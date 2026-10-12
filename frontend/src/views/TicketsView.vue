<script setup>
import { computed, onMounted, ref, watch } from 'vue'
import { RouterLink, useRoute, useRouter } from 'vue-router'
import {
  ArrowRight,
  CheckCircle2,
  Clock3,
  Filter,
  Inbox,
  Plus,
  Search,
  SlidersHorizontal,
  Ticket,
  UserRound,
  X
} from 'lucide-vue-next'
import AppShell from '../components/AppShell.vue'
import { useSupportStore } from '../stores/support'

const store = useSupportStore()
const route = useRoute()
const router = useRouter()

const search = ref(String(route.query.q || ''))
const status = ref(String(route.query.status || 'All'))
const priority = ref(String(route.query.priority || 'All'))
const assignee = ref(String(route.query.assignee || 'All'))

let timer

const rows = computed(() => store.visibleTickets)

const counts = computed(() => {
  const all = rows.value.length
  const open = rows.value.filter(t => t.status === 'Open').length
  const active = rows.value.filter(t => ['Open', 'In Progress', 'Pending'].includes(t.status)).length
  const resolved = rows.value.filter(t => t.status === 'Resolved').length
  const unassigned = rows.value.filter(t => t.assignee === 'Unassigned').length

  return { all, open, active, resolved, unassigned }
})

function formatDate(value) {
  if (!value) return '—'
  return new Date(value).toLocaleString()
}

function initials(name = '') {
  return name
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 2)
    .map(x => x[0]?.toUpperCase())
    .join('') || 'U'
}

async function load() {
  try {
    await store.loadTickets({
      search: search.value.trim(),
      status: status.value,
      priority: priority.value,
      assignee: assignee.value,
    })
  } catch {
    // Store error is rendered.
  }
}

function syncQuery() {
  const query = {}
  if (search.value.trim()) query.q = search.value.trim()
  if (status.value !== 'All') query.status = status.value
  if (priority.value !== 'All') query.priority = priority.value
  if (assignee.value !== 'All') query.assignee = assignee.value

  router.replace({ name: 'tickets', query })
}

function applyFilters() {
  syncQuery()
  load()
}

function clearFilters() {
  search.value = ''
  status.value = 'All'
  priority.value = 'All'
  assignee.value = 'All'
  syncQuery()
  load()
}

watch(search, () => {
  clearTimeout(timer)
  timer = setTimeout(applyFilters, 280)
})

watch([status, priority, assignee], applyFilters)

onMounted(load)
</script>

<template>
  <AppShell>
    <main class="page tickets-page-v2">
      <section class="tickets-hero">
        <div>
          <p class="eyebrow">
            {{ store.role === 'Agent' ? 'TICKET MANAGEMENT' : 'MY SUPPORT REQUESTS' }}
          </p>
          <h1>
            {{ store.role === 'Agent' ? 'All tickets' : 'My tickets' }}
          </h1>
          <p>
            {{ store.role === 'Agent'
              ? 'Search, review, assign and update support requests from the live queue.'
              : 'Track every request you created and continue the conversation with support.' }}
          </p>
        </div>

        <RouterLink v-if="store.role === 'Customer'" class="btn primary tickets-create-btn" to="/tickets/new">
          <Plus :size="14" />
          Create ticket
        </RouterLink>
      </section>

      <section class="tickets-stat-grid">
        <article class="card tickets-stat-card">
          <span class="tickets-stat-icon green"><Ticket :size="17" /></span>
          <div>
            <small>Total tickets</small>
            <strong>{{ counts.all }}</strong>
          </div>
        </article>

        <article class="card tickets-stat-card">
          <span class="tickets-stat-icon cyan"><Clock3 :size="17" /></span>
          <div>
            <small>Active</small>
            <strong>{{ counts.active }}</strong>
          </div>
        </article>

        <article
          v-if="store.role === 'Agent'"
          class="card tickets-stat-card"
        >
          <span class="tickets-stat-icon amber"><UserRound :size="17" /></span>
          <div>
            <small>Unassigned</small>
            <strong>{{ counts.unassigned }}</strong>
          </div>
        </article>

        <article class="card tickets-stat-card">
          <span class="tickets-stat-icon muted"><CheckCircle2 :size="17" /></span>
          <div>
            <small>Resolved</small>
            <strong>{{ counts.resolved }}</strong>
          </div>
        </article>
      </section>

      <section class="card tickets-filter-bar">
        <div class="tickets-search-box">
          <Search :size="15" />
          <input
            v-model="search"
            placeholder="Search ID, title, customer or assignee..."
          />
          <button
            v-if="search"
            type="button"
            class="tickets-clear-search"
            @click="search = ''"
          >
            <X :size="13" />
          </button>
        </div>

        <div class="tickets-filter-group">
          <span class="tickets-filter-label">
            <SlidersHorizontal :size="13" />
            Filters
          </span>

          <select v-model="status">
            <option>All</option>
            <option>Open</option>
            <option>In Progress</option>
            <option>Pending</option>
            <option>Resolved</option>
          </select>

          <select v-model="priority">
            <option>All</option>
            <option>Low</option>
            <option>Medium</option>
            <option>High</option>
            <option>Urgent</option>
          </select>

          <select
            v-if="store.role === 'Agent'"
            v-model="assignee"
          >
            <option>All</option>
            <option
              v-for="a in store.agents"
              :key="a"
            >
              {{ a }}
            </option>
          </select>

          <button class="tickets-clear-btn" type="button" @click="clearFilters">
            Clear
          </button>
        </div>
      </section>

      <div v-if="store.error" class="api-error">
        {{ store.error }}
      </div>

      <section class="card tickets-table-card">
        <div class="tickets-table-headline">
          <div>
            <strong>{{ rows.length }} {{ rows.length === 1 ? 'ticket' : 'tickets' }}</strong>
            <span>
              {{ store.role === 'Agent'
                ? 'Live support queue'
                : 'Requests visible to your account' }}
            </span>
          </div>

          <span class="tickets-live-indicator">
            <i></i>
            AWS API
          </span>
        </div>

        <div v-if="store.loading && !rows.length" class="tickets-loading">
          <div class="tickets-loading-dot"></div>
          Loading tickets from AWS…
        </div>

        <template v-else-if="rows.length">
          <div class="tickets-grid tickets-grid-head">
            <span>Ticket</span>
            <span>Status</span>
            <span>Priority</span>
            <span>{{ store.role === 'Agent' ? 'Customer' : 'Assignee' }}</span>
            <span>Updated</span>
            <span></span>
          </div>

          <button
            v-for="ticket in rows"
            :key="ticket.ticketId"
            class="tickets-grid tickets-row"
            @click="router.push(`/tickets/${ticket.ticketId}`)"
          >
            <span class="tickets-title-cell">
              <small>{{ ticket.ticketId }} · {{ ticket.category }}</small>
              <strong>{{ ticket.title }}</strong>
              <em>
                {{ store.role === 'Agent'
                  ? `Assigned to ${ticket.assignee}`
                  : ticket.description }}
              </em>
            </span>

            <span>
              <span
                class="pill"
                :class="`s-${ticket.status.toLowerCase().replace(' ', '-')}`"
              >
                {{ ticket.status }}
              </span>
            </span>

            <span>
              <span
                class="pill"
                :class="`p-${ticket.priority.toLowerCase()}`"
              >
                {{ ticket.priority }}
              </span>
            </span>

            <span class="tickets-person-cell">
              <span class="tickets-person-avatar">
                {{
                  initials(
                    store.role === 'Agent'
                      ? ticket.customerName
                      : ticket.assignee
                  )
                }}
              </span>

              <span>
                <strong>
                  {{
                    store.role === 'Agent'
                      ? ticket.customerName
                      : ticket.assignee
                  }}
                </strong>

                <small v-if="store.role === 'Agent'">
                  {{ ticket.customerEmail }}
                </small>
              </span>
            </span>

            <span class="tickets-updated-cell">
              {{ formatDate(ticket.updatedAt) }}
            </span>

            <span class="tickets-open-cell">
              <ArrowRight :size="14" />
            </span>
          </button>
        </template>

        <div v-else class="tickets-empty-state">
          <span class="tickets-empty-icon">
            <Inbox :size="24" />
          </span>
          <strong>No tickets found</strong>
          <p>
            {{
              search || status !== 'All' || priority !== 'All' || assignee !== 'All'
                ? 'Try clearing the active filters.'
                : 'Create your first support ticket to get started.'
            }}
          </p>

          <button
            v-if="search || status !== 'All' || priority !== 'All' || assignee !== 'All'"
            class="btn secondary"
            @click="clearFilters"
          >
            <Filter :size="14" />
            Clear filters
          </button>

          <RouterLink
            v-else-if="store.role === 'Customer'"
            class="btn primary"
            to="/tickets/new"
          >
            <Plus :size="14" />
            Create ticket
          </RouterLink>
        </div>
      </section>
    </main>
  </AppShell>
</template>
