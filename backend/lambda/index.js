const { DynamoDBClient } = require("@aws-sdk/client-dynamodb");
const {
  DynamoDBDocumentClient,
  PutCommand,
  GetCommand,
  QueryCommand,
  ScanCommand,
  UpdateCommand,
} = require("@aws-sdk/lib-dynamodb");
const { S3Client, PutObjectCommand, GetObjectCommand } = require("@aws-sdk/client-s3");
const { getSignedUrl } = require("@aws-sdk/s3-request-presigner");
const crypto = require("crypto");

const ddb = DynamoDBDocumentClient.from(new DynamoDBClient({}));
const s3 = new S3Client({});

const TICKETS_TABLE = process.env.TICKETS_TABLE;
const COMMENTS_TABLE = process.env.COMMENTS_TABLE;
const ATTACHMENTS_BUCKET = process.env.ATTACHMENTS_BUCKET;
const CUSTOMER_INDEX = "customerId-createdAt-index";
const MAX_UPLOAD_BYTES = 10 * 1024 * 1024;
const SIGNED_URL_SECONDS = 15 * 60;

function response(statusCode, body) {
  return {
    statusCode,
    headers: { "content-type": "application/json" },
    body: JSON.stringify(body),
  };
}

function claims(event) {
  return event?.requestContext?.authorizer?.jwt?.claims || {};
}

function groupsFromClaims(c) {
  const raw = c["cognito:groups"];
  if (Array.isArray(raw)) return raw;
  if (!raw) return [];
  return String(raw)
    .replace(/^\[/, "")
    .replace(/\]$/, "")
    .split(",")
    .map((x) => x.replace(/["']/g, "").trim())
    .filter(Boolean);
}

function identity(event) {
  const c = claims(event);
  const groups = groupsFromClaims(c);
  return {
    sub: c.sub || "",
    email: c.email || "",
    name: c.name || c.email || "User",
    role: groups.includes("Agents") ? "Agent" : "Customer",
  };
}

function parseBody(event) {
  if (!event.body) return {};
  try {
    return JSON.parse(event.body);
  } catch {
    return null;
  }
}

function safeFileName(name) {
  const clean = String(name || "attachment")
    .replace(/[^a-zA-Z0-9._ -]/g, "_")
    .replace(/\s+/g, "-")
    .slice(-120);
  return clean || "attachment";
}

function newTicketId() {
  return `TKT-${crypto.randomUUID().slice(0, 8).toUpperCase()}`;
}

function newCommentId() {
  return `COM-${Date.now()}-${crypto.randomUUID().slice(0, 6)}`;
}

async function getTicketOrNull(id) {
  const out = await ddb.send(
    new GetCommand({
      TableName: TICKETS_TABLE,
      Key: { ticketId: id },
    })
  );
  return out.Item || null;
}

function canViewTicket(user, ticket) {
  return user.role === "Agent" || ticket.customerId === user.sub;
}

function normalizeList(items) {
  return (items || []).sort((a, b) =>
    String(b.createdAt || "").localeCompare(String(a.createdAt || ""))
  );
}

async function withAttachmentDownloadUrl(ticket) {
  if (!ticket?.attachmentKey || !ATTACHMENTS_BUCKET) return ticket;

  const name = safeFileName(ticket.attachmentName || "attachment");
  const command = new GetObjectCommand({
    Bucket: ATTACHMENTS_BUCKET,
    Key: ticket.attachmentKey,
    ResponseContentDisposition: `attachment; filename="${name}"`,
  });

  const attachmentDownloadUrl = await getSignedUrl(s3, command, {
    expiresIn: SIGNED_URL_SECONDS,
  });

  return {
    ...ticket,
    attachmentDownloadUrl,
    attachmentUrlExpiresIn: SIGNED_URL_SECONDS,
  };
}

async function listTickets(event, user) {
  let items = [];

  if (user.role === "Agent") {
    const out = await ddb.send(
      new ScanCommand({
        TableName: TICKETS_TABLE,
      })
    );
    items = out.Items || [];
  } else {
    const out = await ddb.send(
      new QueryCommand({
        TableName: TICKETS_TABLE,
        IndexName: CUSTOMER_INDEX,
        KeyConditionExpression: "customerId = :customerId",
        ExpressionAttributeValues: {
          ":customerId": user.sub,
        },
        ScanIndexForward: false,
      })
    );
    items = out.Items || [];
  }

  const q = String(event.queryStringParameters?.search || "")
    .trim()
    .toLowerCase();
  const status = String(event.queryStringParameters?.status || "").trim();
  const priority = String(event.queryStringParameters?.priority || "").trim();
  const assignee = String(event.queryStringParameters?.assignee || "").trim();

  if (status) items = items.filter((t) => t.status === status);
  if (priority) items = items.filter((t) => t.priority === priority);
  if (assignee) items = items.filter((t) => t.assignee === assignee);

  if (q) {
    items = items.filter((t) =>
      [
        t.ticketId,
        t.title,
        t.description,
        t.customerName,
        t.customerEmail,
        t.assignee,
        t.category,
      ]
        .map((v) => String(v || "").toLowerCase())
        .some((v) => v.includes(q))
    );
  }

  return response(200, { items: normalizeList(items) });
}

async function createUploadUrl(event, user) {
  if (!ATTACHMENTS_BUCKET) {
    return response(500, { message: "Attachment bucket is not configured." });
  }

  const body = parseBody(event);
  if (!body) return response(400, { message: "Invalid JSON body." });

  const fileName = safeFileName(body.fileName);
  const contentType = String(body.contentType || "application/octet-stream");
  const fileSize = Number(body.fileSize || 0);

  if (!fileName) {
    return response(400, { message: "A file name is required." });
  }

  if (!Number.isFinite(fileSize) || fileSize <= 0) {
    return response(400, { message: "A valid file size is required." });
  }

  if (fileSize > MAX_UPLOAD_BYTES) {
    return response(400, {
      message: "Attachment is too large. Maximum size is 10 MB.",
    });
  }

  const key = `attachments/${user.sub}/${crypto.randomUUID()}-${fileName}`;

  const command = new PutObjectCommand({
    Bucket: ATTACHMENTS_BUCKET,
    Key: key,
    ContentType: contentType,
    Metadata: {
      uploadedBy: user.sub,
      originalName: fileName,
    },
  });

  const uploadUrl = await getSignedUrl(s3, command, {
    expiresIn: SIGNED_URL_SECONDS,
  });

  return response(200, {
    uploadUrl,
    key,
    fileName,
    contentType,
    expiresIn: SIGNED_URL_SECONDS,
    maxBytes: MAX_UPLOAD_BYTES,
  });
}

async function createTicket(event, user) {
  const body = parseBody(event);
  if (!body) return response(400, { message: "Invalid JSON body." });

  const title = String(body.title || "").trim();
  const description = String(body.description || "").trim();
  const priority = String(body.priority || "Medium");
  const category = String(body.category || "General");
  const attachmentKey = body.attachmentKey
    ? String(body.attachmentKey)
    : null;
  const attachmentName = body.attachmentName
    ? safeFileName(body.attachmentName)
    : null;

  if (title.length < 4) {
    return response(400, { message: "Title must be at least 4 characters." });
  }

  if (description.length < 10) {
    return response(400, {
      message: "Description must be at least 10 characters.",
    });
  }

  if (
    attachmentKey &&
    !attachmentKey.startsWith(`attachments/${user.sub}/`)
  ) {
    return response(403, {
      message: "The supplied attachment does not belong to this user.",
    });
  }

  const now = new Date().toISOString();
  const item = {
    ticketId: newTicketId(),
    title,
    description,
    priority,
    category,
    status: "Open",
    customerId: user.sub,
    customerName: user.name,
    customerEmail: user.email,
    assignee: "Unassigned",
    attachmentKey,
    attachmentName,
    createdAt: now,
    updatedAt: now,
    activity: [
      {
        id: crypto.randomUUID(),
        text: attachmentKey
          ? "Ticket created with attachment"
          : "Ticket created",
        createdAt: now,
      },
    ],
  };

  await ddb.send(
    new PutCommand({
      TableName: TICKETS_TABLE,
      Item: item,
      ConditionExpression: "attribute_not_exists(ticketId)",
    })
  );

  return response(201, await withAttachmentDownloadUrl(item));
}

async function getTicket(event, user, id) {
  const ticket = await getTicketOrNull(id);
  if (!ticket) return response(404, { message: "Ticket not found." });

  if (!canViewTicket(user, ticket)) {
    return response(403, { message: "You cannot view this ticket." });
  }

  return response(200, await withAttachmentDownloadUrl(ticket));
}

async function updateTicket(event, user, id) {
  if (user.role !== "Agent") {
    return response(403, { message: "Only Agents can update tickets." });
  }

  const ticket = await getTicketOrNull(id);
  if (!ticket) return response(404, { message: "Ticket not found." });

  const body = parseBody(event);
  if (!body) return response(400, { message: "Invalid JSON body." });

  const allowedStatus = ["Open", "In Progress", "Pending", "Resolved"];
  const allowedPriority = ["Low", "Medium", "High", "Urgent"];

  const nextStatus = body.status ?? ticket.status;
  const nextPriority = body.priority ?? ticket.priority;
  const nextAssignee = body.assignee ?? ticket.assignee;

  if (!allowedStatus.includes(nextStatus)) {
    return response(400, { message: "Invalid status." });
  }

  if (!allowedPriority.includes(nextPriority)) {
    return response(400, { message: "Invalid priority." });
  }

  const now = new Date().toISOString();
  const activity = [...(ticket.activity || [])];

  if (nextStatus !== ticket.status) {
    activity.unshift({
      id: crypto.randomUUID(),
      text: `Status changed from ${ticket.status} to ${nextStatus}`,
      createdAt: now,
    });
  }

  if (nextAssignee !== ticket.assignee) {
    activity.unshift({
      id: crypto.randomUUID(),
      text: `Assigned to ${nextAssignee}`,
      createdAt: now,
    });
  }

  const out = await ddb.send(
    new UpdateCommand({
      TableName: TICKETS_TABLE,
      Key: { ticketId: id },
      UpdateExpression:
        "SET #status = :status, priority = :priority, assignee = :assignee, updatedAt = :updatedAt, activity = :activity",
      ExpressionAttributeNames: {
        "#status": "status",
      },
      ExpressionAttributeValues: {
        ":status": nextStatus,
        ":priority": nextPriority,
        ":assignee": String(nextAssignee || "Unassigned"),
        ":updatedAt": now,
        ":activity": activity,
      },
      ReturnValues: "ALL_NEW",
    })
  );

  return response(200, await withAttachmentDownloadUrl(out.Attributes));
}

async function listComments(user, id) {
  const ticket = await getTicketOrNull(id);
  if (!ticket) return response(404, { message: "Ticket not found." });

  if (!canViewTicket(user, ticket)) {
    return response(403, {
      message: "You cannot view comments for this ticket.",
    });
  }

  const out = await ddb.send(
    new QueryCommand({
      TableName: COMMENTS_TABLE,
      KeyConditionExpression: "ticketId = :ticketId",
      ExpressionAttributeValues: { ":ticketId": id },
      ScanIndexForward: true,
    })
  );

  return response(200, { items: out.Items || [] });
}

async function addComment(event, user, id) {
  const ticket = await getTicketOrNull(id);
  if (!ticket) return response(404, { message: "Ticket not found." });

  if (!canViewTicket(user, ticket)) {
    return response(403, { message: "You cannot comment on this ticket." });
  }

  const body = parseBody(event);
  if (!body) return response(400, { message: "Invalid JSON body." });

  const message = String(body.message || "").trim();
  if (!message) {
    return response(400, { message: "Comment cannot be empty." });
  }

  const now = new Date().toISOString();
  const item = {
    ticketId: id,
    commentId: newCommentId(),
    authorId: user.sub,
    authorName: user.name,
    authorEmail: user.email,
    role: user.role,
    message,
    createdAt: now,
  };

  await ddb.send(
    new PutCommand({
      TableName: COMMENTS_TABLE,
      Item: item,
    })
  );

  const activity = [
    {
      id: crypto.randomUUID(),
      text: `${user.role} added a comment`,
      createdAt: now,
    },
    ...(ticket.activity || []),
  ];

  await ddb.send(
    new UpdateCommand({
      TableName: TICKETS_TABLE,
      Key: { ticketId: id },
      UpdateExpression: "SET updatedAt = :updatedAt, activity = :activity",
      ExpressionAttributeValues: {
        ":updatedAt": now,
        ":activity": activity,
      },
    })
  );

  return response(201, item);
}

exports.handler = async (event) => {
  try {
    const user = identity(event);

    if (!user.sub) {
      return response(401, { message: "Missing authenticated user." });
    }

    const method = event.requestContext?.http?.method;
    const path = event.rawPath || "";
    const id = event.pathParameters?.ticketId;

    if (method === "POST" && path === "/tickets/presigned-url") {
      return await createUploadUrl(event, user);
    }

    if (method === "GET" && path === "/tickets") {
      return await listTickets(event, user);
    }

    if (method === "POST" && path === "/tickets") {
      return await createTicket(event, user);
    }

    if (method === "GET" && id && path === `/tickets/${id}`) {
      return await getTicket(event, user, id);
    }

    if (method === "PUT" && id && path === `/tickets/${id}`) {
      return await updateTicket(event, user, id);
    }

    if (method === "GET" && id && path === `/tickets/${id}/comments`) {
      return await listComments(user, id);
    }

    if (method === "POST" && id && path === `/tickets/${id}/comments`) {
      return await addComment(event, user, id);
    }

    return response(404, { message: "Route not found." });
  } catch (error) {
    console.error(error);
    return response(500, {
      message: "Internal server error.",
      detail: process.env.DEBUG_ERRORS === "true" ? error.message : undefined,
    });
  }
};
