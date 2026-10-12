<script setup>
import { onMounted, reactive, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import {
  FileText,
  FileUp,
  Paperclip,
  Send,
  ShieldCheck,
  TicketCheck,
  X
} from 'lucide-vue-next'
import AppShell from '../components/AppShell.vue'
import { useSupportStore } from '../stores/support'

const store = useSupportStore()
const route = useRoute()
const router = useRouter()

const error = ref('')
const fileInput = ref(null)

const form = reactive({
  title: '',
  description: '',
  priority: 'Medium',
  category: 'Technical',
  file: null,
})

const MAX_BYTES = 10 * 1024 * 1024

// AGENT_CREATE_GUARD
onMounted(() => {
  if (store.role === 'Agent') {
    router.replace('/tickets')
  }
})


onMounted(() => {
  if (typeof route.query.title === 'string') {
    form.title = route.query.title
  }
  if (typeof route.query.priority === 'string') {
    form.priority = route.query.priority
  }
  if (typeof route.query.category === 'string') {
    form.category = route.query.category
  }
  if (typeof route.query.source === 'string') {
    form.description = `Follow-up request for ${route.query.source}.\n\n`
  }
})

function formatBytes(bytes) {
  if (!bytes) return '0 KB'
  const mb = bytes / (1024 * 1024)
  return mb >= 1 ? `${mb.toFixed(2)} MB` : `${Math.ceil(bytes / 1024)} KB`
}

function chooseFile(event) {
  error.value = ''
  const file = event.target.files?.[0]
  if (!file) {
    form.file = null
    return
  }

  if (file.size > MAX_BYTES) {
    error.value = 'Attachment must be 10 MB or smaller.'
    event.target.value = ''
    form.file = null
    return
  }

  form.file = file
}

function removeFile() {
  form.file = null
  if (fileInput.value) fileInput.value.value = ''
}

async function submit() {
  error.value = ''

  if (form.title.trim().length < 4) {
    error.value = 'Title must be at least 4 characters.'
    return
  }

  if (form.description.trim().length < 10) {
    error.value = 'Description must be at least 10 characters.'
    return
  }

  try {
    const ticket = await store.createTicket(form)
    router.push(`/tickets/${ticket.ticketId}`)
  } catch (e) {
    error.value = e.message
  }
}
</script>

<template>
  <AppShell>
    <main class="page create-v3">
      <section class="create-v3-head">
        <div>
          <p class="eyebrow">NEW SUPPORT REQUEST</p>
          <h1>{{ route.query.source ? 'Create a follow-up ticket' : 'Create a ticket' }}</h1>
          <p>
            {{
              route.query.source
                ? `Continue from ${route.query.source} with a new support request.`
                : 'Tell us what happened and add an attachment if needed.'
            }}
          </p>
        </div>

        <span class="create-v3-security">
          <ShieldCheck :size="14" />
          Secure AWS workflow
        </span>
      </section>

      <section class="create-v3-layout">
        <form class="card create-v3-form" @submit.prevent="submit">
          <div class="create-v3-body">
            <div class="create-v3-section">
              <div class="create-v3-section-title">
                <span>01</span>
                <div>
                  <strong>Issue details</strong>
                  <small>Describe the problem clearly.</small>
                </div>
              </div>

              <label class="field">
                <span>Title *</span>
                <input v-model="form.title" placeholder="Short summary of the issue" />
              </label>

              <label class="field">
                <span>Description *</span>
                <textarea
                  v-model="form.description"
                  rows="6"
                  placeholder="Describe what happened, what you expected, and anything you already tried..."
                ></textarea>
              </label>
            </div>

            <div class="create-v3-divider"></div>

            <div class="create-v3-section">
              <div class="create-v3-section-title">
                <span>02</span>
                <div>
                  <strong>Ticket settings</strong>
                  <small>Choose urgency and category.</small>
                </div>
              </div>

              <div class="two">
                <label class="field">
                  <span>Priority</span>
                  <select v-model="form.priority">
                    <option>Low</option>
                    <option>Medium</option>
                    <option>High</option>
                    <option>Urgent</option>
                  </select>
                </label>

                <label class="field">
                  <span>Category</span>
                  <select v-model="form.category">
                    <option>Technical</option>
                    <option>Billing</option>
                    <option>Account</option>
                    <option>General</option>
                    <option>Other</option>
                  </select>
                </label>
              </div>
            </div>

            <div class="create-v3-divider"></div>

            <div class="create-v3-section">
              <div class="create-v3-section-title">
                <span>03</span>
                <div>
                  <strong>Attachment</strong>
                  <small>Optional · maximum 10 MB.</small>
                </div>
              </div>

              <button
                v-if="!form.file"
                type="button"
                class="create-v3-upload"
                @click="fileInput.click()"
              >
                <span class="create-v3-upload-icon"><FileUp :size="20" /></span>
                <span class="create-v3-upload-copy">
                  <strong>Choose a file</strong>
                  <small>PDF, image, text or log file</small>
                </span>
                <span class="create-v3-upload-meta">Private S3</span>
              </button>

              <div v-else class="create-v3-file">
                <span class="create-v3-file-icon"><FileText :size="17" /></span>
                <span class="create-v3-file-copy">
                  <strong>{{ form.file.name }}</strong>
                  <small>{{ formatBytes(form.file.size) }} · {{ form.file.type || 'file' }}</small>
                </span>
                <span class="create-v3-file-ready"><Paperclip :size="12" /> Ready</span>
                <button type="button" class="create-v3-remove" @click="removeFile">
                  <X :size="14" />
                </button>
              </div>

              <input ref="fileInput" type="file" hidden @change="chooseFile" />
            </div>

            <div v-if="store.uploadStage" class="upload-progress">
              <i></i>
              <span>{{ store.uploadStage }}</span>
            </div>

            <p v-if="error" class="error">{{ error }}</p>
          </div>

          <div class="create-v3-actions">
            <button
              type="button"
              class="btn secondary"
              :disabled="store.saving"
              @click="router.push('/tickets')"
            >
              Cancel
            </button>

            <button class="btn primary" type="submit" :disabled="store.saving">
              <Send :size="14" />
              {{ store.saving ? 'Creating…' : 'Create ticket' }}
            </button>
          </div>
        </form>

        <aside class="create-v3-side">
          <article class="card create-v3-preview">
            <div class="create-v3-preview-head">
              <span class="create-v3-preview-icon"><TicketCheck :size="17" /></span>
              <div>
                <strong>Ticket preview</strong>
                <small>Updates while you type</small>
              </div>
            </div>

            <div class="create-v3-preview-main">
              <span class="create-v3-preview-id">NEW TICKET</span>
              <h2>{{ form.title || 'Your ticket title' }}</h2>
              <p>{{ form.description || 'Your description will appear here.' }}</p>
            </div>

            <div class="create-v3-preview-grid">
              <div><span>Priority</span><strong>{{ form.priority }}</strong></div>
              <div><span>Category</span><strong>{{ form.category }}</strong></div>
            </div>

            <div class="create-v3-preview-footer">
              <span>
                <Paperclip :size="12" />
                {{ form.file ? form.file.name : 'No attachment' }}
              </span>
            </div>
          </article>

          <article class="card create-v3-note">
            <ShieldCheck :size="17" />
            <div>
              <strong>Private attachment storage</strong>
              <small>Files upload directly to S3 using a temporary signed URL.</small>
            </div>
          </article>
        </aside>
      </section>
    </main>
  </AppShell>
</template>
