<script setup>
import { reactive, ref } from 'vue'
import { useRouter } from 'vue-router'
import {
  FileText,
  FileUp,
  LockKeyhole,
  Paperclip,
  Send,
  ShieldCheck,
  Sparkles,
  TicketCheck,
  X,
  Zap
} from 'lucide-vue-next'
import AppShell from '../components/AppShell.vue'
import { useSupportStore } from '../stores/support'

const store = useSupportStore()
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

function formatBytes(bytes) {
  if (!bytes) return '0 KB'
  const mb = bytes / (1024 * 1024)
  if (mb >= 1) return `${mb.toFixed(2)} MB`
  return `${Math.ceil(bytes / 1024)} KB`
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
    <main class="page create-page-v2">
      <section class="create-page-head">
        <div>
          <p class="eyebrow">NEW SUPPORT REQUEST</p>
          <h1>Create a ticket</h1>
          <p>
            Tell us what happened. Ticket data is stored in DynamoDB and
            attachments upload securely to private Amazon S3 storage.
          </p>
        </div>

        <div class="create-head-badge">
          <ShieldCheck :size="16" />
          <span>
            <strong>Secure by design</strong>
            <small>Cognito + private S3</small>
          </span>
        </div>
      </section>

      <section class="create-layout">
        <form class="card form-card create-main-card" @submit.prevent="submit">
          <div class="form-body">
            <div class="create-section-label">
              <span>01</span>
              <div>
                <strong>Describe the issue</strong>
                <small>Give your support request a clear title and description.</small>
              </div>
            </div>

            <label class="field">
              <span>Title *</span>
              <input
                v-model="form.title"
                placeholder="Short summary of the issue"
              />
            </label>

            <label class="field">
              <span>Description *</span>
              <textarea
                v-model="form.description"
                rows="7"
                placeholder="Describe what happened and what you expected..."
              ></textarea>
            </label>

            <div class="create-section-label second">
              <span>02</span>
              <div>
                <strong>Classify the request</strong>
                <small>Help the support team understand urgency and category.</small>
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

            <div class="create-section-label second">
              <span>03</span>
              <div>
                <strong>Add supporting evidence</strong>
                <small>Optional — attach an image, PDF or log file up to 10 MB.</small>
              </div>
            </div>

            <button
              v-if="!form.file"
              type="button"
              class="upload create-upload"
              @click="fileInput.click()"
            >
              <span class="upload-visual">
                <FileUp :size="24" />
              </span>
              <strong>Choose attachment</strong>
              <span>Upload directly to private S3 storage · Maximum 10 MB</span>
            </button>

            <div v-else class="selected-file">
              <span class="selected-file-icon">
                <FileText :size="18" />
              </span>

              <span class="selected-file-copy">
                <strong>{{ form.file.name }}</strong>
                <small>
                  {{ formatBytes(form.file.size) }}
                  · {{ form.file.type || 'application/octet-stream' }}
                </small>
              </span>

              <span class="s3-ready">
                <Paperclip :size="13" />
                Ready for S3
              </span>

              <button
                type="button"
                class="remove-file"
                title="Remove attachment"
                @click="removeFile"
              >
                <X :size="15" />
              </button>
            </div>

            <input
              ref="fileInput"
              type="file"
              hidden
              @change="chooseFile"
            />

            <div v-if="store.uploadStage" class="upload-progress">
              <i></i>
              <span>{{ store.uploadStage }}</span>
            </div>

            <p v-if="error" class="error">{{ error }}</p>
          </div>

          <div class="form-foot create-form-foot">
            <button
              type="button"
              class="btn secondary"
              :disabled="store.saving"
              @click="router.push('/tickets')"
            >
              Cancel
            </button>

            <button
              class="btn primary"
              type="submit"
              :disabled="store.saving"
            >
              <Send :size="14" />
              {{ store.saving ? 'Please wait…' : 'Create ticket' }}
            </button>
          </div>
        </form>

        <aside class="create-side">
          <article class="card create-floating-card create-preview-card">
            <span class="create-side-icon green">
              <TicketCheck :size="19" />
            </span>
            <p class="eyebrow">TICKET PREVIEW</p>
            <h2>{{ form.title || 'Your ticket title' }}</h2>
            <p>
              {{ form.description || 'Your description will appear here as you type.' }}
            </p>

            <div class="create-preview-meta">
              <div>
                <span>Priority</span>
                <strong>{{ form.priority }}</strong>
              </div>
              <div>
                <span>Category</span>
                <strong>{{ form.category }}</strong>
              </div>
              <div>
                <span>Attachment</span>
                <strong>{{ form.file ? '1 file' : 'None' }}</strong>
              </div>
            </div>
          </article>

          <article class="card create-floating-card">
            <span class="create-side-icon cyan">
              <Zap :size="19" />
            </span>
            <h3>What happens next?</h3>

            <div class="create-step">
              <span>1</span>
              <div>
                <strong>Ticket is created</strong>
                <small>Your request is saved in DynamoDB.</small>
              </div>
            </div>

            <div class="create-step">
              <span>2</span>
              <div>
                <strong>Agent reviews it</strong>
                <small>An Agent can assign and update the request.</small>
              </div>
            </div>

            <div class="create-step">
              <span>3</span>
              <div>
                <strong>You track progress</strong>
                <small>Comments and activity remain visible on the ticket.</small>
              </div>
            </div>
          </article>

          <article class="card create-floating-card create-security-card">
            <LockKeyhole :size="16" />
            <div>
              <strong>Private attachment storage</strong>
              <small>Files use short-lived S3 presigned URLs.</small>
            </div>
            <Sparkles :size="15" />
          </article>
        </aside>
      </section>
    </main>
  </AppShell>
</template>
