<script setup>
import { onMounted, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { Plus, Search } from 'lucide-vue-next'
import AppShell from '../components/AppShell.vue'
import { useSupportStore } from '../stores/support'

const store = useSupportStore()
const route = useRoute()
const router = useRouter()
const search = ref(typeof route.query.q === 'string' ? route.query.q : '')
const status = ref(typeof route.query.status === 'string' ? route.query.status : 'All')
const priority = ref('All')
let timer

async function load() { try { await store.loadTickets({ search: search.value, status: status.value, priority: priority.value }) } catch {} }
watch([search, status, priority], () => { clearTimeout(timer); timer = setTimeout(load, 250) })
onMounted(load)
function clearAll() { search.value = ''; status.value = 'All'; priority.value = 'All'; router.replace('/tickets'); load() }
</script>

<template>
  <AppShell>
    <main class="page">
      <section class="hero">
        <div><p class="eyebrow">TICKET MANAGEMENT</p><h1>{{ store.role === 'Agent' ? 'All tickets' : 'My tickets' }}</h1><p>{{ store.role === 'Agent' ? 'Search, open, assign and update support requests.' : 'Search and track your own support requests.' }}</p></div>
        <button class="btn primary" @click="router.push('/tickets/new')"><Plus :size="15" /> Create ticket</button>
      </section>

      <section class="card filters aws-filters">
        <label class="search-field"><Search :size="15" /><input v-model="search" placeholder="Search ID, title, customer or assignee..." /></label>
        <select v-model="status"><option>All</option><option>Open</option><option>In Progress</option><option>Pending</option><option>Resolved</option></select>
        <select v-model="priority"><option>All</option><option>Urgent</option><option>High</option><option>Medium</option><option>Low</option></select>
        <button class="btn secondary" @click="clearAll">Clear</button>
      </section>

      <div v-if="store.error" class="api-error">{{ store.error }}</div>

      <section class="card table-card">
        <div class="toolbar"><span><strong>{{ store.tickets.length }}</strong> ticket{{ store.tickets.length === 1 ? '' : 's' }}</span><span>{{ store.loading ? 'Refreshing from AWS…' : (store.role === 'Customer' ? 'API returns only your tickets.' : 'API returns the whole queue.') }}</span></div>
        <div class="thead tgrid"><span>Ticket</span><span>Status</span><span>Priority</span><span>{{ store.role === 'Agent' ? 'Customer' : 'Assignee' }}</span><span>Updated</span></div>
        <button v-for="t in store.tickets" :key="t.ticketId" class="trow tgrid" @click="router.push(`/tickets/${t.ticketId}`)">
          <span class="titlecell"><small>{{ t.ticketId }}</small><strong>{{ t.title }}</strong><em>{{ t.category }}</em></span>
          <span class="pill" :class="`s-${t.status.toLowerCase().replace(' ', '-')}`">{{ t.status }}</span>
          <span class="pill" :class="`p-${t.priority.toLowerCase()}`">{{ t.priority }}</span>
          <span>{{ store.role === 'Agent' ? t.customerName : t.assignee }}</span>
          <span class="faded">{{ new Date(t.updatedAt).toLocaleString() }}</span>
        </button>
        <div v-if="!store.loading && !store.tickets.length" class="empty">No tickets match the current filters.</div>
      </section>
    </main>
  </AppShell>
</template>
