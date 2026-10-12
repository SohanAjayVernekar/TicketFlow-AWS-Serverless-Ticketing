import { defineStore } from 'pinia'
import { ticketApi } from '../services/api'

export const useSupportStore = defineStore('support', {
  state: () => ({
    role: 'Customer',
    currentUser: { id:'', name:'Customer', email:'' },
    agents: ['Unassigned','Aarav Shah','Maya Rao','Rohan Mehta','Nisha Patel'],
    tickets: [],
    activeTicket: null,
    comments: [],
    loading: false,
    saving: false,
    uploadStage: '',
    error: '',
  }),

  getters: {
    visibleTickets(state) {
      return state.tickets
    },
    openCount() {
      return this.visibleTickets.filter(
        t => ['Open','In Progress','Pending'].includes(t.status)
      ).length
    },
    resolvedCount() {
      return this.visibleTickets.filter(t => t.status === 'Resolved').length
    },
    unassignedCount() {
      return this.visibleTickets.filter(t => t.assignee === 'Unassigned').length
    },
  },

  actions: {
    setAuthContext(role, identity) {
      this.role = role
      this.currentUser = {
        id: identity.id || '',
        name: identity.name || identity.email || 'Customer',
        email: identity.email || '',
      }
    },

    async loadTickets(params = {}) {
      this.loading = true
      this.error = ''

      try {
        const data = await ticketApi.list(params)
        this.tickets = data.items || []
        return this.tickets
      } catch (e) {
        this.error = e.message
        throw e
      } finally {
        this.loading = false
      }
    },

    async loadTicket(ticketId) {
      this.loading = true
      this.error = ''

      try {
        const [ticket, comments] = await Promise.all([
          ticketApi.get(ticketId),
          ticketApi.listComments(ticketId),
        ])

        this.activeTicket = ticket
        this.comments = comments.items || []

        const idx = this.tickets.findIndex(
          t => t.ticketId === ticket.ticketId
        )

        if (idx >= 0) this.tickets[idx] = ticket

        return ticket
      } catch (e) {
        this.error = e.message
        throw e
      } finally {
        this.loading = false
      }
    },

    async createTicket(data) {
      this.saving = true
      this.uploadStage = ''
      this.error = ''

      try {
        let attachmentKey = null
        let attachmentName = null

        if (data.file) {
          this.uploadStage = 'Preparing secure upload…'
          const signed = await ticketApi.createPresignedUrl(data.file)

          this.uploadStage = 'Uploading attachment to S3…'
          await ticketApi.uploadFile(
            signed.uploadUrl,
            data.file,
            signed.contentType
          )

          attachmentKey = signed.key
          attachmentName = signed.fileName
        }

        this.uploadStage = 'Creating ticket…'

        const created = await ticketApi.create({
          title: data.title,
          description: data.description,
          priority: data.priority,
          category: data.category,
          attachmentKey,
          attachmentName,
        })

        this.tickets.unshift(created)
        this.uploadStage = ''
        return created
      } catch (e) {
        this.error = e.message
        this.uploadStage = ''
        throw e
      } finally {
        this.saving = false
      }
    },

    async updateTicket(ticketId, data) {
      this.saving = true
      this.error = ''

      try {
        const updated = await ticketApi.update(ticketId, data)
        this.activeTicket = updated

        const idx = this.tickets.findIndex(
          t => t.ticketId === updated.ticketId
        )

        if (idx >= 0) this.tickets[idx] = updated

        return updated
      } catch (e) {
        this.error = e.message
        throw e
      } finally {
        this.saving = false
      }
    },

    async addComment(ticketId, message) {
      this.saving = true
      this.error = ''

      try {
        const comment = await ticketApi.addComment(ticketId, message)
        this.comments.push(comment)
        await this.loadTicket(ticketId)
        return comment
      } catch (e) {
        this.error = e.message
        throw e
      } finally {
        this.saving = false
      }
    },

    resetDemo() {
      this.tickets = []
      this.activeTicket = null
      this.comments = []
    },
  }
})
