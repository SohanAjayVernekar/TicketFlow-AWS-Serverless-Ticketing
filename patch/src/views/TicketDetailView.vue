<script setup>
import { computed, onMounted, reactive, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import {
  ArrowLeft,
  Download,
  FileText,
  MessageSquare,
  Paperclip,
  Save,
  Send
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

const edit = reactive({
  status: '',
  priority: '',
  assignee: '',
})

const ticket = computed(() => store.activeTicket)

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

async function add() {
  if (!ticket.value || !comment.value.trim()) return

  localError.value = ''

  try {
    await store.addComment(ticket.value.ticketId, comment.value)
    comment.value = ''
  } catch (e) {
    localError.value = e.message
  }
}

async function openAttachment() {
  if (!ticket.value?.attachmentKey) return

  localError.value = ''
  openingAttachment.value = true

  try {
    // Reload first so the S3 download URL is always fresh.
    const fresh = await store.loadTicket(ticket.value.ticketId)

    if (!fresh.attachmentDownloadUrl) {
      throw new Error('Attachment download URL is unavailable.')
    }

    window.open(
      fresh.attachmentDownloadUrl,
      '_blank',
      'noopener,noreferrer'
    )
  } catch (e) {
    localError.value = e.message
  } finally {
    openingAttachment.value = false
  }
}
</script>

<template>
  <AppShell>
    <main class="page">
      <button class="back" @click="router.push('/tickets')">
        <ArrowLeft :size="14" /> Back to tickets
      </button>

      <div v-if="store.loading && !ticket" class="loading-box">
        Loading ticket from AWS…
      </div>

      <div v-else-if="localError && !ticket" class="api-error">
        {{ localError }}
      </div>

      <template v-else-if="ticket">
        <section class="detail-hero">
          <div>
            <p class="eyebrow">{{ ticket.ticketId }}</p>
            <h1>{{ ticket.title }}</h1>
            <p>
              Created {{ new Date(ticket.createdAt).toLocaleString() }}
              · Updated {{ new Date(ticket.updatedAt).toLocaleString() }}
            </p>
          </div>

          <span
            class="pill big"
            :class="`s-${ticket.status.toLowerCase().replace(' ', '-')}`"
          >
            {{ ticket.status }}
          </span>
        </section>

        <div v-if="localError" class="api-error">
          {{ localError }}
        </div>

        <div class="detail-grid">
          <section class="detail-main">
            <article class="card detail-card">
              <h2>Description</h2>
              <p>{{ ticket.description }}</p>

              <div
                v-if="ticket.attachmentKey"
                class="attachment s3-attachment"
              >
                <span class="attachment-file-icon">
                  <FileText :size="17" />
                </span>

                <span>
                  <strong>
                    {{ ticket.attachmentName || 'Attachment' }}
                  </strong>
                  <small>
                    Private S3 object · temporary download link generated securely
                  </small>
                </span>

                <button
                  class="download-attachment"
                  :disabled="openingAttachment"
                  @click="openAttachment"
                >
                  <Download :size="13" />
                  {{ openingAttachment ? 'Opening…' : 'Download' }}
                </button>
              </div>
            </article>

            <article class="card detail-card">
              <h2>Activity</h2>

              <div class="timeline">
                <div
                  v-for="a in ticket.activity || []"
                  :key="a.id"
                >
                  <i></i>
                  <span>
                    <strong>{{ a.text }}</strong>
                    <small>
                      {{ new Date(a.createdAt).toLocaleString() }}
                    </small>
                  </span>
                </div>
              </div>
            </article>

            <article class="card detail-card">
              <h2 class="with-icon">
                <MessageSquare :size="15" /> Comments
              </h2>

              <div v-if="store.comments.length" class="comments">
                <div
                  v-for="c in store.comments"
                  :key="c.commentId"
                  class="comment"
                >
                  <span class="comment-avatar">
                    {{ c.authorName.charAt(0) }}
                  </span>

                  <div>
                    <div class="comment-meta">
                      <strong>{{ c.authorName }}</strong>
                      <span>
                        {{ c.role }}
                        · {{ new Date(c.createdAt).toLocaleString() }}
                      </span>
                    </div>

                    <p>{{ c.message }}</p>
                  </div>
                </div>
              </div>

              <div v-else class="empty small">
                No comments yet.
              </div>

              <form class="comment-form" @submit.prevent="add">
                <textarea
                  v-model="comment"
                  rows="3"
                  placeholder="Write a comment..."
                ></textarea>

                <button
                  class="btn primary"
                  type="submit"
                  :disabled="store.saving"
                >
                  <Send :size="14" />
                  {{ store.saving ? 'Saving…' : 'Add comment' }}
                </button>
              </form>
            </article>
          </section>

          <aside class="detail-side">
            <article class="card side-card">
              <h2>Ticket information</h2>

              <label class="field">
                <span>Status</span>
                <select
                  v-model="edit.status"
                  :disabled="store.role !== 'Agent'"
                >
                  <option>Open</option>
                  <option>In Progress</option>
                  <option>Pending</option>
                  <option>Resolved</option>
                </select>
              </label>

              <label class="field">
                <span>Priority</span>
                <select
                  v-model="edit.priority"
                  :disabled="store.role !== 'Agent'"
                >
                  <option>Low</option>
                  <option>Medium</option>
                  <option>High</option>
                  <option>Urgent</option>
                </select>
              </label>

              <label class="field">
                <span>Assignee</span>
                <select
                  v-model="edit.assignee"
                  :disabled="store.role !== 'Agent'"
                >
                  <option
                    v-for="a in store.agents"
                    :key="a"
                  >
                    {{ a }}
                  </option>
                </select>
              </label>

              <div class="side-row">
                <span>Category</span>
                <strong>{{ ticket.category }}</strong>
              </div>

              <button
                v-if="store.role === 'Agent'"
                class="btn primary full"
                :disabled="store.saving"
                @click="save"
              >
                <Save :size="14" />
                {{ store.saving ? 'Saving…' : 'Save changes' }}
              </button>

              <p v-else class="note">
                Customers can comment and track status.
                Only Agents can change status, priority and assignee.
              </p>

              <p v-if="saved" class="saved">
                Changes saved in DynamoDB.
              </p>
            </article>

            <article class="card side-card">
              <h2>Customer</h2>

              <div class="customer">
                <span class="comment-avatar">
                  {{ ticket.customerName.charAt(0) }}
                </span>

                <div>
                  <strong>{{ ticket.customerName }}</strong>
                  <small>{{ ticket.customerEmail }}</small>
                </div>
              </div>
            </article>
          </aside>
        </div>
      </template>
    </main>
  </AppShell>
</template>
