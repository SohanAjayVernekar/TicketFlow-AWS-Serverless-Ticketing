const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
const { DynamoDBDocumentClient, PutCommand, GetCommand, QueryCommand, ScanCommand, UpdateCommand } = require('@aws-sdk/lib-dynamodb');
const crypto = require('crypto');

const db = DynamoDBDocumentClient.from(new DynamoDBClient({}));
const TICKETS_TABLE = process.env.TICKETS_TABLE;
const COMMENTS_TABLE = process.env.COMMENTS_TABLE;
const CUSTOMER_INDEX = 'customerId-createdAt-index';

const reply = (statusCode, body) => ({ statusCode, headers: { 'content-type': 'application/json' }, body: JSON.stringify(body) });

function userFrom(event) {
  const c = event?.requestContext?.authorizer?.jwt?.claims || {};
  const raw = c['cognito:groups'];
  const groups = Array.isArray(raw) ? raw : String(raw || '').replace(/^\[/,'').replace(/\]$/,'').split(',').map(x => x.replace(/["']/g,'').trim()).filter(Boolean);
  return {
    sub: c.sub || '',
    email: c.email || '',
    name: c.name || c.email || 'User',
    role: groups.includes('Agents') ? 'Agent' : 'Customer'
  };
}

function body(event) {
  try { return event.body ? JSON.parse(event.body) : {}; }
  catch { return null; }
}

async function getTicket(id) {
  const out = await db.send(new GetCommand({ TableName: TICKETS_TABLE, Key: { ticketId: id } }));
  return out.Item || null;
}

const canView = (u, t) => u.role === 'Agent' || t.customerId === u.sub;

async function listTickets(event, u) {
  let items = [];
  if (u.role === 'Agent') {
    const out = await db.send(new ScanCommand({ TableName: TICKETS_TABLE }));
    items = out.Items || [];
  } else {
    const out = await db.send(new QueryCommand({
      TableName: TICKETS_TABLE,
      IndexName: CUSTOMER_INDEX,
      KeyConditionExpression: 'customerId = :c',
      ExpressionAttributeValues: { ':c': u.sub },
      ScanIndexForward: false
    }));
    items = out.Items || [];
  }

  const q = String(event.queryStringParameters?.search || '').trim().toLowerCase();
  const status = String(event.queryStringParameters?.status || '').trim();
  const priority = String(event.queryStringParameters?.priority || '').trim();
  if (status) items = items.filter(t => t.status === status);
  if (priority) items = items.filter(t => t.priority === priority);
  if (q) items = items.filter(t => [t.ticketId,t.title,t.description,t.customerName,t.customerEmail,t.assignee,t.category].some(v => String(v || '').toLowerCase().includes(q)));
  items.sort((a,b) => String(b.createdAt || '').localeCompare(String(a.createdAt || '')));
  return reply(200, { items });
}

async function createTicket(event, u) {
  const b = body(event);
  if (!b) return reply(400, { message: 'Invalid JSON body.' });
  const title = String(b.title || '').trim();
  const description = String(b.description || '').trim();
  if (title.length < 4) return reply(400, { message: 'Title must be at least 4 characters.' });
  if (description.length < 10) return reply(400, { message: 'Description must be at least 10 characters.' });
  const now = new Date().toISOString();
  const item = {
    ticketId: `TKT-${crypto.randomUUID().slice(0,8).toUpperCase()}`,
    title,
    description,
    priority: String(b.priority || 'Medium'),
    category: String(b.category || 'General'),
    status: 'Open',
    customerId: u.sub,
    customerName: u.name,
    customerEmail: u.email,
    assignee: 'Unassigned',
    attachmentName: b.attachmentName || null,
    attachmentKey: null,
    createdAt: now,
    updatedAt: now,
    activity: [{ id: crypto.randomUUID(), text: 'Ticket created', createdAt: now }]
  };
  await db.send(new PutCommand({ TableName: TICKETS_TABLE, Item: item, ConditionExpression: 'attribute_not_exists(ticketId)' }));
  return reply(201, item);
}

async function readTicket(u, id) {
  const t = await getTicket(id);
  if (!t) return reply(404, { message: 'Ticket not found.' });
  if (!canView(u,t)) return reply(403, { message: 'You cannot view this ticket.' });
  return reply(200, t);
}

async function updateTicket(event, u, id) {
  if (u.role !== 'Agent') return reply(403, { message: 'Only Agents can update tickets.' });
  const t = await getTicket(id);
  if (!t) return reply(404, { message: 'Ticket not found.' });
  const b = body(event);
  if (!b) return reply(400, { message: 'Invalid JSON body.' });
  const nextStatus = b.status ?? t.status;
  const nextPriority = b.priority ?? t.priority;
  const nextAssignee = b.assignee ?? t.assignee;
  if (!['Open','In Progress','Pending','Resolved'].includes(nextStatus)) return reply(400, { message: 'Invalid status.' });
  if (!['Low','Medium','High','Urgent'].includes(nextPriority)) return reply(400, { message: 'Invalid priority.' });
  const now = new Date().toISOString();
  const activity = [...(t.activity || [])];
  if (nextStatus !== t.status) activity.unshift({ id: crypto.randomUUID(), text: `Status changed from ${t.status} to ${nextStatus}`, createdAt: now });
  if (nextAssignee !== t.assignee) activity.unshift({ id: crypto.randomUUID(), text: `Assigned to ${nextAssignee}`, createdAt: now });
  const out = await db.send(new UpdateCommand({
    TableName: TICKETS_TABLE,
    Key: { ticketId: id },
    UpdateExpression: 'SET #s=:s, priority=:p, assignee=:a, updatedAt=:u, activity=:act',
    ExpressionAttributeNames: { '#s': 'status' },
    ExpressionAttributeValues: { ':s': nextStatus, ':p': nextPriority, ':a': String(nextAssignee || 'Unassigned'), ':u': now, ':act': activity },
    ReturnValues: 'ALL_NEW'
  }));
  return reply(200, out.Attributes);
}

async function listComments(u, id) {
  const t = await getTicket(id);
  if (!t) return reply(404, { message: 'Ticket not found.' });
  if (!canView(u,t)) return reply(403, { message: 'You cannot view comments for this ticket.' });
  const out = await db.send(new QueryCommand({
    TableName: COMMENTS_TABLE,
    KeyConditionExpression: 'ticketId = :t',
    ExpressionAttributeValues: { ':t': id },
    ScanIndexForward: true
  }));
  return reply(200, { items: out.Items || [] });
}

async function addComment(event, u, id) {
  const t = await getTicket(id);
  if (!t) return reply(404, { message: 'Ticket not found.' });
  if (!canView(u,t)) return reply(403, { message: 'You cannot comment on this ticket.' });
  const b = body(event);
  if (!b) return reply(400, { message: 'Invalid JSON body.' });
  const message = String(b.message || '').trim();
  if (!message) return reply(400, { message: 'Comment cannot be empty.' });
  const now = new Date().toISOString();
  const item = {
    ticketId: id,
    commentId: `COM-${Date.now()}-${crypto.randomUUID().slice(0,6)}`,
    authorId: u.sub,
    authorName: u.name,
    authorEmail: u.email,
    role: u.role,
    message,
    createdAt: now
  };
  await db.send(new PutCommand({ TableName: COMMENTS_TABLE, Item: item }));
  const activity = [{ id: crypto.randomUUID(), text: `${u.role} added a comment`, createdAt: now }, ...(t.activity || [])];
  await db.send(new UpdateCommand({
    TableName: TICKETS_TABLE,
    Key: { ticketId: id },
    UpdateExpression: 'SET updatedAt=:u, activity=:a',
    ExpressionAttributeValues: { ':u': now, ':a': activity }
  }));
  return reply(201, item);
}

exports.handler = async (event) => {
  try {
    const u = userFrom(event);
    if (!u.sub) return reply(401, { message: 'Missing authenticated user.' });
    const method = event.requestContext?.http?.method;
    const path = event.rawPath || '';
    const id = event.pathParameters?.ticketId;
    if (method === 'GET' && path === '/tickets') return await listTickets(event,u);
    if (method === 'POST' && path === '/tickets') return await createTicket(event,u);
    if (method === 'GET' && id && path === `/tickets/${id}`) return await readTicket(u,id);
    if (method === 'PUT' && id && path === `/tickets/${id}`) return await updateTicket(event,u,id);
    if (method === 'GET' && id && path === `/tickets/${id}/comments`) return await listComments(u,id);
    if (method === 'POST' && id && path === `/tickets/${id}/comments`) return await addComment(event,u,id);
    return reply(404, { message: 'Route not found.' });
  } catch (err) {
    console.error(err);
    return reply(500, { message: 'Internal server error.' });
  }
};
