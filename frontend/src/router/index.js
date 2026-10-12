import { createRouter, createWebHistory } from 'vue-router'
import LandingView from '../views/LandingView.vue'
import LoginView from '../views/LoginView.vue'
import AuthCallbackView from '../views/AuthCallbackView.vue'
import DashboardView from '../views/DashboardView.vue'
import TicketsView from '../views/TicketsView.vue'
import CreateTicketView from '../views/CreateTicketView.vue'
import TicketDetailView from '../views/TicketDetailView.vue'
import { getAuthUser } from '../auth/cognito'

const router = createRouter({
  history: createWebHistory(),
  routes: [
    {
      path: '/',
      name: 'landing',
      component: LandingView,
      meta: { public: true },
    },
    {
      path: '/login',
      name: 'login',
      component: LoginView,
      meta: { public: true },
    },
    {
      path: '/auth/callback',
      name: 'auth-callback',
      component: AuthCallbackView,
      meta: { public: true },
    },
    {
      path: '/dashboard',
      name: 'dashboard',
      component: DashboardView,
    },
    {
      path: '/tickets',
      name: 'tickets',
      component: TicketsView,
    },
    {
      path: '/tickets/new',
      name: 'ticket-create',
      component: CreateTicketView,
    },
    {
      path: '/tickets/:ticketId',
      name: 'ticket-detail',
      component: TicketDetailView,
    },
  ],
})

router.beforeEach(async (to) => {
  if (to.meta.public) return true

  try {
    const user = await getAuthUser()

    if (!user) {
      return {
        name: 'login',
        query: { redirect: to.fullPath },
      }
    }

    return true
  } catch {
    return {
      name: 'login',
      query: { redirect: to.fullPath },
    }
  }
})

export default router
