import { getAuthUser } from '../auth/cognito'

const baseUrl = (import.meta.env.VITE_API_BASE_URL || '').replace(/\/$/, '')

async function authToken() {
  const user = await getAuthUser()
  if (!user?.id_token) throw new Error('You are not signed in.')
  return user.id_token
}

async function request(path, options = {}) {
  if (!baseUrl) {
    throw new Error(
      'VITE_API_BASE_URL is not configured. Provision the backend and restart Vite.'
    )
  }

  const token = await authToken()

  const response = await fetch(`${baseUrl}${path}`, {
    ...options,
    headers: {
      'content-type': 'application/json',
      Authorization: `Bearer ${token}`,
      ...(options.headers || {}),
    },
  })

  const text = await response.text()
  let data = {}

  try {
    data = text ? JSON.parse(text) : {}
  } catch {
    data = { message: text }
  }

  if (!response.ok) {
    const error = new Error(
      data?.message || `Request failed (${response.status})`
    )
    error.status = response.status
    error.data = data
    throw error
  }

  return data
}

async function uploadFileToSignedUrl(uploadUrl, file, contentType) {
  const response = await fetch(uploadUrl, {
    method: 'PUT',
    headers: {
      'Content-Type': contentType || 'application/octet-stream',
    },
    body: file,
  })

  if (!response.ok) {
    throw new Error(`S3 upload failed (${response.status}).`)
  }

  return true
}

export const ticketApi = {
  list(params = {}) {
    const search = new URLSearchParams()

    if (params.search) search.set('search', params.search)
    if (params.status && params.status !== 'All') {
      search.set('status', params.status)
    }
    if (params.priority && params.priority !== 'All') {
      search.set('priority', params.priority)
    }
    if (params.assignee && params.assignee !== 'All') {
      search.set('assignee', params.assignee)
    }

    const qs = search.toString()
    return request(`/tickets${qs ? `?${qs}` : ''}`)
  },

  create(payload) {
    return request('/tickets', {
      method: 'POST',
      body: JSON.stringify(payload),
    })
  },

  createPresignedUrl(file) {
    return request('/tickets/presigned-url', {
      method: 'POST',
      body: JSON.stringify({
        fileName: file.name,
        contentType: file.type || 'application/octet-stream',
        fileSize: file.size,
      }),
    })
  },

  uploadFile(uploadUrl, file, contentType) {
    return uploadFileToSignedUrl(uploadUrl, file, contentType)
  },

  get(ticketId) {
    return request(`/tickets/${encodeURIComponent(ticketId)}`)
  },

  update(ticketId, payload) {
    return request(`/tickets/${encodeURIComponent(ticketId)}`, {
      method: 'PUT',
      body: JSON.stringify(payload),
    })
  },

  listComments(ticketId) {
    return request(`/tickets/${encodeURIComponent(ticketId)}/comments`)
  },

  addComment(ticketId, message) {
    return request(`/tickets/${encodeURIComponent(ticketId)}/comments`, {
      method: 'POST',
      body: JSON.stringify({ message }),
    })
  },
}
