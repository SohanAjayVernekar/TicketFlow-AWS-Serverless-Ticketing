import { createRouter, createWebHistory } from 'vue-router'
import DashboardView from '../views/DashboardView.vue'
import TicketsView from '../views/TicketsView.vue'
import CreateTicketView from '../views/CreateTicketView.vue'
import TicketDetailView from '../views/TicketDetailView.vue'
import LoginView from '../views/LoginView.vue'
import AuthCallbackView from '../views/AuthCallbackView.vue'
import { cognitoConfigured, getAuthUser } from '../auth/cognito'

const router = createRouter({
  history: createWebHistory(),
  routes: [
    { path: '/login', name: 'login', component: LoginView, meta: { public: true } },
    { path: '/auth/callback', name: 'auth-callback', component: AuthCallbackView, meta: { public: true } },
    { path: '/', name: 'dashboard', component: DashboardView },
    { path: '/tickets', name: 'tickets', component: TicketsView },
    { path: '/tickets/new', name: 'ticket-create', component: CreateTicketView },
    { path: '/tickets/:ticketId', name: 'ticket-detail', component: TicketDetailView },
    { path: '/:pathMatch(.*)*', redirect: '/' },
  ],
  scrollBehavior: () => ({ top: 0 }),
})

router.beforeEach(async (to) => {
  if (to.meta.public) {
    if (to.name === 'login' && cognitoConfigured) {
      const existing = await getAuthUser()
      if (existing) return { name: 'dashboard' }
    }
    return true
  }

  if (!cognitoConfigured) {
    return { name: 'login', query: { setup: '1' } }
  }

  const user = await getAuthUser()
  if (user) return true

  return {
    name: 'login',
    query: { redirect: to.fullPath },
  }
})

export default router
