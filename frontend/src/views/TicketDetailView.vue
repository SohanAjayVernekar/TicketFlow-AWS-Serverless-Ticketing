<script setup>
import { computed, onMounted, reactive, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import {
  ArrowLeft,
  CalendarClock,
  CheckCircle2,
  Clipboard,
  Copy,
  Download,
  FileDown,
  FileText,
  Link2,
  Mail,
  MessageSquare,
  Paperclip,
  PauseCircle,
  Play,
  RefreshCw,
  Save,
  Send,
  Sparkles,
  Tag,
  UserCheck,
  UserRound
} from 'lucide-vue-next'
import AppShell from '../components/AppShell.vue'
import { useSupportStore } from '../stores/support'

const store = useSupportStore()
const route = useRoute()
const router = useRouter()

const comment = ref('')
const saved = ref(false)
const localError = ref('')
const openingAttachment = ref(false)
const actionMessage = ref('')

const edit = reactive({
  status: '',
  priority: '',
  assignee: '',
})

const ticket = computed(() => store.activeTicket)

const customerTemplates = [
  'Could you please share an update on this ticket?',
  'The issue is still happening on my side.',
  'I tried the suggested steps, but the problem is not resolved yet.',
  'Thank you. The issue is working correctly now.',
]

const agentTemplates = [
  'Thanks for the details. I am reviewing this now.',
  'I am investigating the issue and will update the ticket shortly.',
  'Could you please share a screenshot or any additional error details?',
  'The issue has been resolved. Please confirm that everything is working correctly.',
]

const replyTemplates = computed(() =>
  store.role === 'Agent' ? agentTemplates : customerTemplates
)

const progress = computed(() => {
  const current = ticket.value?.status || 'Open'
  const order = ['Open', 'In Progress', 'Pending', 'Resolved']
  const currentIndex = order.indexOf(current)

  return order.map((label, index) => ({
    label,
    done: current === 'Resolved' ? true : index <= currentIndex,
    active: label === current,
  }))
})

watch(
  ticket,
  (t) => {
    if (!t) return
    edit.status = t.status
    edit.priority = t.priority
    edit.assignee = t.assignee
  },
  { immediate: true }
)

onMounted(async () => {
  try {
    await store.loadTicket(String(route.params.ticketId))
  } catch (e) {
    localError.value = e.message
  }
})

function flash(message) {
  actionMessage.value = message
  window.setTimeout(() => {
    actionMessage.value = ''
  }, 1800)
}

async function copyText(value, successMessage) {
  try {
    await navigator.clipboard.writeText(value)
    flash(successMessage)
  } catch {
    localError.value = 'Could not copy to clipboard.'
  }
}

function copyTicketId() {
  if (ticket.value?.ticketId) {
    copyText(ticket.value.ticketId, 'Ticket ID copied')
  }
}

function copyTicketLink() {
  copyText(window.location.href, 'Ticket link copied')
}

function exportTicket() {
  if (!ticket.value) return

  const t = ticket.value
  const comments = store.comments
    .map(c => `[${formatDate(c.createdAt)}] ${c.authorName} (${c.role}): ${c.message}`)
    .join('\n')

  const activity = (t.activity || [])
    .map(a => `[${formatDate(a.createdAt)}] ${a.text}`)
    .join('\n')

  const content = [
    `TicketFlow Ticket Summary`,
    `=========================`,
    ``,
    `Ticket ID: ${t.ticketId}`,
    `Title: ${t.title}`,
    `Status: ${t.status}`,
    `Priority: ${t.priority}`,
    `Category: ${t.category}`,
    `Assignee: ${t.assignee}`,
    `Customer: ${t.customerName}`,
    `Customer Email: ${t.customerEmail}`,
    `Created: ${formatDate(t.createdAt)}`,
    `Updated: ${formatDate(t.updatedAt)}`,
    ``,
    `Description`,
    `-----------`,
    t.description,
    ``,
    `Activity`,
    `--------`,
    activity || 'No activity',
    ``,
    `Comments`,
    `--------`,
    comments || 'No comments',
  ].join('\n')

  const blob = new Blob([content], { type: 'text/plain;charset=utf-8' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = `${t.ticketId}-summary.txt`
  document.body.appendChild(a)
  a.click()
  a.remove()
  URL.revokeObjectURL(url)
  flash('Ticket summary downloaded')
}

function useTemplate(text) {
  comment.value = text
}

function createSimilarTicket() {
  if (!ticket.value || store.role === 'Agent') return

  router.push({
    name: 'ticket-create',
    query: {
      title: `Follow-up: ${ticket.value.title}`,
      priority: ticket.value.priority,
      category: ticket.value.category,
      source: ticket.value.ticketId,
    },
  })
}

async function save() {
  if (!ticket.value) return
  localError.value = ''

  try {
    await store.updateTicket(ticket.value.ticketId, {
      status: edit.status,
      priority: edit.priority,
      assignee: edit.assignee,
    })

    saved.value = true
    setTimeout(() => {
      saved.value = false
    }, 1500)
  } catch (e) {
    localError.value = e.message
  }
}

async function quickUpdate(patch, message) {
  if (!ticket.value || store.role !== 'Agent') return
  localError.value = ''

  try {
    const next = {
      status: patch.status ?? edit.status,
      priority: patch.priority ?? edit.priority,
      assignee: patch.assignee ?? edit.assignee,
    }

    const updated = await store.updateTicket(ticket.value.ticketId, next)
    edit.status = updated.status
    edit.priority = updated.priority
    edit.assignee = updated.assignee
    flash(message)
  } catch (e) {
    localError.value = e.message
  }
}

function assignToMe() {
  const name = store.currentUser?.name || store.currentUser?.email || 'Agent'
  quickUpdate({ assignee: name }, `Assigned to ${name}`)
}

function startWork() {
  quickUpdate({ status: 'In Progress' }, 'Ticket moved to In Progress')
}

function markPending() {
  quickUpdate({ status: 'Pending' }, 'Ticket marked Pending')
}

function resolveTicket() {
  quickUpdate({ status: 'Resolved' }, 'Ticket resolved')
}

async function add() {
  if (!ticket.value || !comment.value.trim()) return
  localError.value = ''

  try {
    await store.addComment(ticket.value.ticketId, comment.value)
    comment.value = ''
    flash('Comment added')
  } catch (e) {
    localError.value = e.message
  }
}

async function openAttachment() {
  if (!ticket.value?.attachmentKey) return

  localError.value = ''
  openingAttachment.value = true

  try {
    const fresh = await store.loadTicket(ticket.value.ticketId)

    if (!fresh.attachmentDownloadUrl) {
      throw new Error('Attachment download URL is unavailable.')
    }

    window.open(fresh.attachmentDownloadUrl, '_blank', 'noopener,noreferrer')
  } catch (e) {
    localError.value = e.message
  } finally {
    openingAttachment.value = false
  }
}

function initials(name = '') {
  return name
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((x) => x[0]?.toUpperCase())
    .join('') || 'U'
}

function formatDate(value) {
  if (!value) return '—'
  return new Date(value).toLocaleString()
}
</script>

<template>
  <AppShell>
    <main class="page ticket-detail-v2 ticket-feature-pack">
      <div class="ticket-top-actions">
        <button class="ticket-back" @click="router.push('/tickets')">
          <ArrowLeft :size="14" />
          Back to tickets
        </button>

        <div class="ticket-utility-actions">
          <button @click="copyTicketId">
            <Copy :size="13" />
            Copy ID
          </button>
          <button @click="copyTicketLink">
            <Link2 :size="13" />
            Copy link
          </button>
          <button @click="exportTicket">
            <FileDown :size="13" />
            Export
          </button>
          <button
            v-if="store.role !== 'Agent'"
            class="customer-followup-btn"
            @click="createSimilarTicket"
          >
            <RefreshCw :size="13" />
            Create follow-up
          </button>
        </div>
      </div>

      <div v-if="actionMessage" class="ticket-action-toast">
        <CheckCircle2 :size="14" />
        {{ actionMessage }}
      </div>

      <div v-if="store.loading && !ticket" class="loading-box">
        Loading ticket from AWS…
      </div>

      <div v-else-if="localError && !ticket" class="api-error">
        {{ localError }}
      </div>

      <template v-else-if="ticket">
        <section class="ticket-detail-hero">
          <div class="ticket-detail-hero-copy">
            <div class="ticket-detail-eyebrow">
              <span>{{ ticket.ticketId }}</span>
              <span class="hero-separator">•</span>
              <span>{{ ticket.category }}</span>
            </div>

            <h1>{{ ticket.title }}</h1>

            <div class="ticket-detail-meta">
              <span>
                <CalendarClock :size="13" />
                Created {{ formatDate(ticket.createdAt) }}
              </span>
              <span>Updated {{ formatDate(ticket.updatedAt) }}</span>
            </div>
          </div>

          <div class="ticket-hero-status">
            <span
              class="pill big"
              :class="`s-${ticket.status.toLowerCase().replace(' ', '-')}`"
            >
              {{ ticket.status }}
            </span>
            <small>{{ ticket.priority }} priority</small>
          </div>
        </section>

        <section class="ticket-progress-card">
          <div
            v-for="(step, index) in progress"
            :key="step.label"
            class="ticket-progress-step"
            :class="{ done: step.done, active: step.active }"
          >
            <span>
              <CheckCircle2 v-if="step.done" :size="13" />
              <span v-else>{{ index + 1 }}</span>
            </span>
            <strong>{{ step.label }}</strong>
            <i v-if="index < progress.length - 1"></i>
          </div>
        </section>

        <div v-if="localError" class="api-error">{{ localError }}</div>

        <section class="ticket-detail-layout">
          <div class="ticket-detail-main">
            <article class="card ticket-panel ticket-description-panel">
              <div class="ticket-panel-head">
                <div>
                  <span class="ticket-panel-icon"><FileText :size="15" /></span>
                  <div>
                    <h2>Description</h2>
                    <p>Customer-reported issue</p>
                  </div>
                </div>
              </div>

              <div class="ticket-description-copy">{{ ticket.description }}</div>

              <div v-if="ticket.attachmentKey" class="ticket-attachment-card">
                <span class="ticket-attachment-icon"><Paperclip :size="17" /></span>

                <span class="ticket-attachment-copy">
                  <strong>{{ ticket.attachmentName || 'Attachment' }}</strong>
                  <small>Private S3 attachment · secure temporary access</small>
                </span>

                <button
                  class="download-attachment ticket-download-btn"
                  :disabled="openingAttachment"
                  @click="openAttachment"
                >
                  <Download :size="13" />
                  {{ openingAttachment ? 'Opening…' : 'Download' }}
                </button>
              </div>
            </article>

            <article class="card ticket-panel">
              <div class="ticket-panel-head">
                <div>
                  <span class="ticket-panel-icon cyan"><Sparkles :size="15" /></span>
                  <div>
                    <h2>Activity</h2>
                    <p>Everything that happened on this ticket</p>
                  </div>
                </div>
              </div>

              <div class="ticket-activity-list">
                <div
                  v-for="(a, index) in ticket.activity || []"
                  :key="a.id"
                  class="ticket-activity-item"
                >
                  <span class="ticket-activity-rail">
                    <i></i>
                    <b v-if="index !== (ticket.activity || []).length - 1"></b>
                  </span>

                  <div>
                    <strong>{{ a.text }}</strong>
                    <small>{{ formatDate(a.createdAt) }}</small>
                  </div>
                </div>
              </div>
            </article>

            <article class="card ticket-panel">
              <div class="ticket-panel-head">
                <div>
                  <span class="ticket-panel-icon amber"><MessageSquare :size="15" /></span>
                  <div>
                    <h2>Conversation</h2>
                    <p>Customer and Agent replies</p>
                  </div>
                </div>

                <span class="comment-count">
                  {{ store.comments.length }}
                  {{ store.comments.length === 1 ? 'comment' : 'comments' }}
                </span>
              </div>

              <div v-if="store.comments.length" class="ticket-comments">
                <div
                  v-for="c in store.comments"
                  :key="c.commentId"
                  class="ticket-comment"
                >
                  <span
                    class="ticket-comment-avatar"
                    :class="{ agent: c.role === 'Agent' }"
                  >
                    {{ initials(c.authorName) }}
                  </span>

                  <div class="ticket-comment-body">
                    <div class="ticket-comment-meta">
                      <span>
                        <strong>{{ c.authorName }}</strong>
                        <em>{{ c.role }}</em>
                      </span>
                      <small>{{ formatDate(c.createdAt) }}</small>
                    </div>

                    <p>{{ c.message }}</p>
                  </div>
                </div>
              </div>

              <div v-else class="ticket-empty-comments">
                <MessageSquare :size="22" />
                <strong>No comments yet</strong>
                <span>Start the conversation below.</span>
              </div>

              <div class="quick-reply-wrap">
                <span>Quick replies</span>
                <div>
                  <button
                    v-for="template in replyTemplates"
                    :key="template"
                    type="button"
                    @click="useTemplate(template)"
                  >
                    {{ template }}
                  </button>
                </div>
              </div>

              <form class="ticket-comment-form" @submit.prevent="add">
                <textarea
                  v-model="comment"
                  rows="4"
                  placeholder="Write a comment..."
                ></textarea>

                <div class="ticket-comment-actions">
                  <span>
                    Your reply will be visible to
                    {{ store.role === 'Agent' ? 'the customer' : 'the support team' }}.
                  </span>

                  <button
                    class="btn primary"
                    type="submit"
                    :disabled="store.saving || !comment.trim()"
                  >
                    <Send :size="14" />
                    {{ store.saving ? 'Saving…' : 'Add comment' }}
                  </button>
                </div>
              </form>
            </article>
          </div>

          <aside class="ticket-detail-side">
            <article
              v-if="store.role === 'Agent'"
              class="card ticket-side-card agent-quick-actions"
            >
              <div class="ticket-side-head">
                <div>
                  <h2>Agent quick actions</h2>
                  <p>Common queue operations</p>
                </div>
              </div>

              <button @click="assignToMe">
                <UserCheck :size="14" />
                Assign to me
              </button>
              <button @click="startWork">
                <Play :size="14" />
                Start work
              </button>
              <button @click="markPending">
                <PauseCircle :size="14" />
                Mark pending
              </button>
              <button class="resolve-action" @click="resolveTicket">
                <CheckCircle2 :size="14" />
                Resolve ticket
              </button>
            </article>

            <article class="card ticket-side-card ticket-info-card">
              <div class="ticket-side-head">
                <div>
                  <h2>Ticket information</h2>
                  <p>Manage the support request</p>
                </div>
                <span class="ticket-side-status-dot"></span>
              </div>

              <label class="field">
                <span>Status</span>
                <select v-model="edit.status" :disabled="store.role !== 'Agent'">
                  <option>Open</option>
                  <option>In Progress</option>
                  <option>Pending</option>
                  <option>Resolved</option>
                </select>
              </label>

              <label class="field">
                <span>Priority</span>
                <select v-model="edit.priority" :disabled="store.role !== 'Agent'">
                  <option>Low</option>
                  <option>Medium</option>
                  <option>High</option>
                  <option>Urgent</option>
                </select>
              </label>

              <label class="field">
                <span>Assignee</span>
                <select v-model="edit.assignee" :disabled="store.role !== 'Agent'">
                  <option v-for="a in store.agents" :key="a">{{ a }}</option>
                </select>
              </label>

              <div class="ticket-side-row">
                <span><Tag :size="13" /> Category</span>
                <strong>{{ ticket.category }}</strong>
              </div>

              <button
                v-if="store.role === 'Agent'"
                class="btn primary full ticket-save-btn"
                :disabled="store.saving"
                @click="save"
              >
                <Save :size="14" />
                {{ store.saving ? 'Saving…' : 'Save changes' }}
              </button>

              <p v-else class="note">
                Only Agents can change status, priority, and assignee.
              </p>

              <div v-if="saved" class="ticket-save-success">
                <CheckCircle2 :size="14" />
                Changes saved successfully
              </div>
            </article>

            <article class="card ticket-side-card ticket-customer-card">
              <div class="ticket-side-head">
                <div>
                  <h2>Customer</h2>
                  <p>Ticket owner</p>
                </div>
              </div>

              <div class="ticket-customer-profile">
                <span class="ticket-customer-avatar">{{ initials(ticket.customerName) }}</span>

                <div>
                  <strong>{{ ticket.customerName }}</strong>
                  <small>{{ ticket.customerEmail }}</small>
                </div>
              </div>

              <div class="ticket-customer-row">
                <UserRound :size="13" />
                <span>Customer account</span>
              </div>

              <div class="ticket-customer-row">
                <Mail :size="13" />
                <span>{{ ticket.customerEmail }}</span>
              </div>
            </article>
          </aside>
        </section>
      </template>
    </main>
  </AppShell>
</template>
