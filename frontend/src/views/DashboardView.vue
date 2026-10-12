<script setup>
import { computed, onMounted } from 'vue'
import { RouterLink, useRouter } from 'vue-router'
import {
  AlertTriangle,
  ArrowRight,
  CheckCircle2,
  Clock3,
  Headphones,
  Inbox,
  MessageSquare,
  Plus,
  ShieldCheck,
  Ticket,
  UserRound,
  UsersRound
} from 'lucide-vue-next'
import AppShell from '../components/AppShell.vue'
import { useSupportStore } from '../stores/support'

const store = useSupportStore()
const router = useRouter()

onMounted(async () => {
  try {
    await store.loadTickets()
  } catch {
    // Store already exposes API errors to the UI.
  }
})

const recent = computed(() => store.visibleTickets.slice(0, 5))

const counts = computed(() => {
  const out = {
    Open: 0,
    'In Progress': 0,
    Pending: 0,
    Resolved: 0,
    Urgent: 0,
  }

  for (const ticket of store.visibleTickets) {
    if (out[ticket.status] !== undefined) out[ticket.status]++
    if (ticket.priority === 'Urgent' && ticket.status !== 'Resolved') out.Urgent++
  }

  return out
})

const activeCount = computed(
  () => counts.value.Open + counts.value['In Progress'] + counts.value.Pending
)

const awaitingAgent = computed(
  () => store.visibleTickets.filter((t) => t.assignee === 'Unassigned' && t.status !== 'Resolved').length
)

const total = computed(() => Math.max(store.visibleTickets.length, 1))

const statusWidth = (count) => `${Math.max(8, (count / total.value) * 100)}%`
</script>

<template>
  <AppShell>
    <main class="page role-dashboard">
      <div v-if="store.error" class="api-error">{{ store.error }}</div>

      <div v-if="store.loading && !store.tickets.length" class="loading-box">
        Loading your AWS ticket dashboard…
      </div>

      <!-- =========================================================
           AGENT DASHBOARD
           ========================================================= -->
      <template v-else-if="store.role === 'Agent'">
        <section class="agent-hero">
          <div>
            <div class="role-kicker agent-kicker">
              <Headphones :size="14" />
              AGENT WORKSPACE
            </div>
            <h1>Support control center</h1>
            <p>
              Review the complete ticket queue, pick up unassigned work,
              respond to customers, and move issues toward resolution.
            </p>
          </div>

          <div class="hero-actions">
            <RouterLink class="btn secondary" to="/tickets">
              <Inbox :size="15" /> Open queue
            </RouterLink>
            <RouterLink v-if="store.role === 'Customer'" class="btn primary" to="/tickets/new">
              <Plus :size="15" /> Create ticket
            </RouterLink>
          </div>
        </section>

        <section class="agent-metrics">
          <button class="agent-metric card" @click="router.push('/tickets')">
            <span class="metric-icon green"><Ticket :size="17" /></span>
            <div>
              <small>Total queue</small>
              <strong>{{ store.visibleTickets.length }}</strong>
              <em>All customer tickets</em>
            </div>
          </button>

          <button
            class="agent-metric card"
            @click="router.push({ name: 'tickets', query: { status: 'Open' } })"
          >
            <span class="metric-icon cyan"><Clock3 :size="17" /></span>
            <div>
              <small>Active tickets</small>
              <strong>{{ activeCount }}</strong>
              <em>Need support attention</em>
            </div>
          </button>

          <button
            class="agent-metric card"
            @click="router.push({ name: 'tickets', query: { assignee: 'Unassigned' } })"
          >
            <span class="metric-icon amber"><UsersRound :size="17" /></span>
            <div>
              <small>Unassigned</small>
              <strong>{{ store.unassignedCount }}</strong>
              <em>Waiting for an owner</em>
            </div>
          </button>

          <button
            class="agent-metric card"
            @click="router.push({ name: 'tickets', query: { status: 'Resolved' } })"
          >
            <span class="metric-icon muted-icon"><CheckCircle2 :size="17" /></span>
            <div>
              <small>Resolved</small>
              <strong>{{ store.resolvedCount }}</strong>
              <em>Completed requests</em>
            </div>
          </button>
        </section>

        <section class="agent-grid">
          <article class="card queue-health">
            <div class="role-card-head">
              <div>
                <h2>Queue health</h2>
                <p>Live ticket distribution from DynamoDB</p>
              </div>
              <RouterLink to="/tickets">
                View queue <ArrowRight :size="13" />
              </RouterLink>
            </div>

            <div class="agent-status-list">
              <div>
                <span>Open</span>
                <i><b class="bar-open" :style="{ width: statusWidth(counts.Open) }"></b></i>
                <strong>{{ counts.Open }}</strong>
              </div>
              <div>
                <span>In progress</span>
                <i><b class="bar-progress" :style="{ width: statusWidth(counts['In Progress']) }"></b></i>
                <strong>{{ counts['In Progress'] }}</strong>
              </div>
              <div>
                <span>Pending</span>
                <i><b class="bar-pending" :style="{ width: statusWidth(counts.Pending) }"></b></i>
                <strong>{{ counts.Pending }}</strong>
              </div>
              <div>
                <span>Resolved</span>
                <i><b class="bar-resolved" :style="{ width: statusWidth(counts.Resolved) }"></b></i>
                <strong>{{ counts.Resolved }}</strong>
              </div>
            </div>
          </article>

          <article class="card attention-card">
            <div class="role-card-head">
              <div>
                <h2>Needs attention</h2>
                <p>Important parts of the support queue</p>
              </div>
            </div>

            <button
              class="attention-item"
              @click="router.push({ name: 'tickets', query: { assignee: 'Unassigned' } })"
            >
              <span class="attention-icon amber">
                <UserRound :size="16" />
              </span>
              <span>
                <strong>Unassigned tickets</strong>
                <small>Tickets that do not have an agent yet</small>
              </span>
              <b>{{ store.unassignedCount }}</b>
            </button>

            <button class="attention-item" @click="router.push('/tickets')">
              <span class="attention-icon pink">
                <AlertTriangle :size="16" />
              </span>
              <span>
                <strong>Urgent tickets</strong>
                <small>High-impact requests that need quick review</small>
              </span>
              <b>{{ counts.Urgent }}</b>
            </button>

            <button
              class="attention-item"
              @click="router.push({ name: 'tickets', query: { status: 'Pending' } })"
            >
              <span class="attention-icon cyan">
                <Clock3 :size="16" />
              </span>
              <span>
                <strong>Pending tickets</strong>
                <small>Waiting on a follow-up or next action</small>
              </span>
              <b>{{ counts.Pending }}</b>
            </button>
          </article>
        </section>

        <section class="card role-table-card">
          <div class="role-card-head">
            <div>
              <h2>Recent support queue</h2>
              <p>Latest tickets visible to the Agent role</p>
            </div>
            <RouterLink to="/tickets">
              All tickets <ArrowRight :size="13" />
            </RouterLink>
          </div>

          <div class="thead role-table-grid">
            <span>Ticket</span>
            <span>Status</span>
            <span>Priority</span>
            <span>Customer</span>
            <span>Assignee</span>
          </div>

          <button
            v-for="ticket in recent"
            :key="ticket.ticketId"
            class="trow role-table-grid"
            @click="router.push(`/tickets/${ticket.ticketId}`)"
          >
            <span class="titlecell">
              <small>{{ ticket.ticketId }}</small>
              <strong>{{ ticket.title }}</strong>
            </span>
            <span
              class="pill"
              :class="`s-${ticket.status.toLowerCase().replace(' ', '-')}`"
            >
              {{ ticket.status }}
            </span>
            <span
              class="pill"
              :class="`p-${ticket.priority.toLowerCase()}`"
            >
              {{ ticket.priority }}
            </span>
            <span>{{ ticket.customerName }}</span>
            <span class="faded">{{ ticket.assignee }}</span>
          </button>

          <div v-if="!recent.length" class="empty">
            The support queue is empty.
          </div>
        </section>
      </template>

      <!-- =========================================================
           CUSTOMER DASHBOARD
           ========================================================= -->
      <template v-else>
        <section class="customer-hero">
          <div class="customer-hero-copy">
            <div class="role-kicker customer-kicker">
              <ShieldCheck :size="14" />
              CUSTOMER SUPPORT
            </div>
            <h1>How can we help?</h1>
            <p>
              Welcome, {{ store.currentUser.name }}. Create a support request,
              follow its progress, and continue the conversation with our support team.
            </p>

            <div class="customer-hero-actions">
              <RouterLink v-if="store.role === 'Customer'" class="btn primary customer-main-cta" to="/tickets/new">
                <Plus :size="15" /> Create support ticket
              </RouterLink>
              <RouterLink class="btn secondary" to="/tickets">
                <Ticket :size="15" /> View my tickets
              </RouterLink>
            </div>
          </div>

          <div class="customer-hero-visual">
            <span class="support-ring ring-one"></span>
            <span class="support-ring ring-two"></span>
            <div class="support-center">
              <Headphones :size="30" />
              <strong>Support</strong>
              <span>We’re here to help</span>
            </div>
          </div>
        </section>

        <section class="customer-metrics">
          <RouterLink class="customer-stat card" to="/tickets">
            <span class="customer-stat-icon green">
              <Ticket :size="18" />
            </span>
            <div>
              <strong>{{ store.visibleTickets.length }}</strong>
              <span>My tickets</span>
            </div>
          </RouterLink>

          <RouterLink
            class="customer-stat card"
            :to="{ name: 'tickets', query: { status: 'Open' } }"
          >
            <span class="customer-stat-icon cyan">
              <Clock3 :size="18" />
            </span>
            <div>
              <strong>{{ activeCount }}</strong>
              <span>Active</span>
            </div>
          </RouterLink>

          <RouterLink
            class="customer-stat card"
            :to="{ name: 'tickets', query: { status: 'Resolved' } }"
          >
            <span class="customer-stat-icon muted-icon">
              <CheckCircle2 :size="18" />
            </span>
            <div>
              <strong>{{ store.resolvedCount }}</strong>
              <span>Resolved</span>
            </div>
          </RouterLink>

          <RouterLink class="customer-stat card" to="/tickets">
            <span class="customer-stat-icon amber">
              <UserRound :size="18" />
            </span>
            <div>
              <strong>{{ awaitingAgent }}</strong>
              <span>Awaiting agent</span>
            </div>
          </RouterLink>
        </section>

        <section class="customer-grid">
          <article class="card customer-recent">
            <div class="role-card-head">
              <div>
                <h2>My recent requests</h2>
                <p>Your latest support conversations</p>
              </div>
              <RouterLink to="/tickets">
                View all <ArrowRight :size="13" />
              </RouterLink>
            </div>

            <button
              v-for="ticket in recent"
              :key="ticket.ticketId"
              class="customer-ticket"
              @click="router.push(`/tickets/${ticket.ticketId}`)"
            >
              <span class="customer-ticket-icon">
                <MessageSquare :size="16" />
              </span>

              <span class="customer-ticket-copy">
                <small>{{ ticket.ticketId }} · {{ ticket.category }}</small>
                <strong>{{ ticket.title }}</strong>
                <em>
                  {{ ticket.assignee === 'Unassigned'
                    ? 'Waiting for an agent'
                    : `Assigned to ${ticket.assignee}` }}
                </em>
              </span>

              <span
                class="pill"
                :class="`s-${ticket.status.toLowerCase().replace(' ', '-')}`"
              >
                {{ ticket.status }}
              </span>

              <ArrowRight :size="14" class="customer-ticket-arrow" />
            </button>

            <div v-if="!recent.length" class="customer-empty">
              <span class="customer-empty-icon">
                <Ticket :size="24" />
              </span>
              <strong>You don’t have any support tickets yet.</strong>
              <p>Create your first ticket and our support team can start helping you.</p>
              <RouterLink v-if="store.role === 'Customer'" class="btn primary" to="/tickets/new">
                <Plus :size="14" /> Create ticket
              </RouterLink>
            </div>
          </article>

          <aside class="card customer-help">
            <div class="role-card-head">
              <div>
                <h2>How support works</h2>
                <p>Three simple steps</p>
              </div>
            </div>

            <div class="help-step">
              <span>1</span>
              <div>
                <strong>Create your ticket</strong>
                <p>Tell us what happened and choose the right priority and category.</p>
              </div>
            </div>

            <div class="help-step">
              <span>2</span>
              <div>
                <strong>An agent reviews it</strong>
                <p>Your ticket is assigned and the support team can update its status.</p>
              </div>
            </div>

            <div class="help-step">
              <span>3</span>
              <div>
                <strong>Continue the conversation</strong>
                <p>Add comments and track every update from your ticket detail page.</p>
              </div>
            </div>

            <RouterLink v-if="store.role === 'Customer'" class="customer-help-link" to="/tickets/new">
              Need help now? Create a ticket <ArrowRight :size="13" />
            </RouterLink>
          </aside>
        </section>
      </template>
    </main>
  </AppShell>
</template>
