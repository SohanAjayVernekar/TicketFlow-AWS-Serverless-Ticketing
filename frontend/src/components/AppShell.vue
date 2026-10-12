<script setup>
import { computed, onMounted, ref } from 'vue'
import { RouterLink, useRoute, useRouter } from 'vue-router'
import {
  Bell,
  LayoutDashboard,
  LogOut,
  Plus,
  Search,
  Ticket,
  UserRound,
  Zap
} from 'lucide-vue-next'
import {
  getAuthUser,
  getIdentity,
  getRole,
  signOut
} from '../auth/cognito'
import { useSupportStore } from '../stores/support'

const store = useSupportStore()
const route = useRoute()
const router = useRouter()

const search = ref('')
const showBell = ref(false)
const showProfile = ref(false)
const authIdentity = ref({ id: '', name: 'User', email: '' })

const pageName = computed(() => ({
  dashboard: store.role === 'Agent' ? 'Agent Dashboard' : 'Customer Dashboard',
  tickets: store.role === 'Agent' ? 'All Tickets' : 'My Tickets',
  'ticket-create': 'Create Ticket',
  'ticket-detail': String(route.params.ticketId || 'Ticket'),
}[String(route.name)] || 'TicketFlow'))

const alerts = computed(() => {
  const list = []

  if (store.role === 'Agent' && store.unassignedCount) {
    list.push(`${store.unassignedCount} unassigned ticket${store.unassignedCount === 1 ? '' : 's'}`)
  }

  const urgent = store.visibleTickets.filter(
    (t) => t.priority === 'Urgent' && t.status !== 'Resolved'
  ).length

  if (urgent) {
    list.push(`${urgent} urgent ticket${urgent === 1 ? '' : 's'}`)
  }

  return list.length ? list : ['No new support alerts']
})

const initials = computed(() => {
  const text = authIdentity.value.name || authIdentity.value.email || 'U'
  return text
    .split(/\s+/)
    .slice(0, 2)
    .map((x) => x[0]?.toUpperCase())
    .join('')
})

onMounted(async () => {
  const user = await getAuthUser()
  if (!user) return

  const identity = getIdentity(user)
  const role = getRole(user)

  authIdentity.value = identity
  store.setAuthContext(role, identity)
})

function submitSearch() {
  const q = search.value.trim()
  router.push({
    name: 'tickets',
    query: q ? { q } : {},
  })
}

async function logout() {
  showProfile.value = false
  await signOut()
}
</script>

<template>
  <div class="app-bg workspace-animated">
    <div class="workspace-noise"></div>
    <div class="ws-orb ws-orb-a"></div>
    <div class="ws-orb ws-orb-b"></div>
    <div class="ws-orb ws-orb-c"></div>

    <div class="app-frame glass-frame">
      <header class="topbar elevated-topbar">
        <div class="top-left">
          <RouterLink to="/dashboard" class="logo">
            <Zap :size="18" />
          </RouterLink>

          <span
            class="role-badge"
            :class="store.role === 'Agent' ? 'agent-role-badge' : 'customer-role-badge'"
          >
            <UserRound :size="13" />
            {{ store.role }}
          </span>

          <span class="slash">/</span>
          <strong class="page-name">{{ pageName }}</strong>
        </div>

        <nav class="main-nav">
          <RouterLink
            to="/dashboard"
            :class="{ active: route.name === 'dashboard' }"
          >
            <LayoutDashboard :size="16" />
            <span>Dashboard</span>
          </RouterLink>

          <RouterLink
            to="/tickets"
            :class="{ active: ['tickets', 'ticket-detail'].includes(String(route.name)) }"
          >
            <Ticket :size="16" />
            <span>{{ store.role === 'Agent' ? 'All tickets' : 'My tickets' }}</span>
          </RouterLink>

          <RouterLink
            to="/tickets/new"
            :class="{ active: route.name === 'ticket-create' }"
          >
            <Plus :size="16" />
            <span>New ticket</span>
          </RouterLink>
        </nav>

        <div class="actions">
          <form class="top-search glass-search" @submit.prevent="submitSearch">
            <Search :size="15" />
            <input
              v-model="search"
              :placeholder="store.role === 'Agent'
                ? 'Search the support queue...'
                : 'Search my tickets...'"
            />
          </form>

          <div class="pop-wrap">
            <button
              class="icon-btn glass-icon-btn"
              @click="showBell = !showBell; showProfile = false"
            >
              <Bell :size="16" />
            </button>

            <div v-if="showBell" class="popover floating-popover">
              <h4>Notifications</h4>
              <button
                v-for="alert in alerts"
                :key="alert"
                @click="router.push('/tickets'); showBell = false"
              >
                {{ alert }}
              </button>
            </div>
          </div>

          <div class="pop-wrap">
            <button
              class="avatar floating-avatar"
              @click="showProfile = !showProfile; showBell = false"
            >
              {{ initials || 'U' }}
            </button>

            <div v-if="showProfile" class="popover profile floating-popover">
              <strong>{{ authIdentity.name }}</strong>
              <span>{{ authIdentity.email }}</span>
              <em>{{ store.role }} access</em>
              <button class="logout-action" @click="logout">
                <LogOut :size="13" /> Sign out
              </button>
            </div>
          </div>
        </div>
      </header>

      <div class="workspace-shell">
        <slot />
      </div>
    </div>
  </div>
</template>
