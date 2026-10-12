<script setup>
import { reactive, ref } from 'vue'
import { useRouter } from 'vue-router'
import {
  FileText,
  FileUp,
  Paperclip,
  Send,
  X
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
    <main class="page narrow">
      <section class="hero">
        <div>
          <p class="eyebrow">NEW SUPPORT REQUEST</p>
          <h1>Create a ticket</h1>
          <p>
            Ticket data is stored in DynamoDB and attachments upload
            directly to private Amazon S3 storage.
          </p>
        </div>
      </section>

      <form class="card form-card" @submit.prevent="submit">
        <div class="form-body">
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

          <button
            v-if="!form.file"
            type="button"
            class="upload"
            @click="fileInput.click()"
          >
            <FileUp :size="22" />
            <strong>Choose attachment</strong>
            <span>
              Upload directly to private S3 storage · Maximum 10 MB
            </span>
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

        <div class="form-foot">
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
    </main>
  </AppShell>
</template>
