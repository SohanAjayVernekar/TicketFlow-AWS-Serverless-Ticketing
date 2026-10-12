<script setup>
import { computed, onMounted, ref } from 'vue'
import { useRoute } from 'vue-router'
import {
  ArrowRight,
  Headphones,
  LockKeyhole,
  ShieldCheck,
  Ticket,
  UserRound,
  UsersRound,
  Zap
} from 'lucide-vue-next'
import {
  cognitoConfigured,
  signIn,
  startCustomerSignup,
  takeLoginError
} from '../auth/cognito'

const route = useRoute()
const busy = ref('')
const error = ref('')

const redirectTo = computed(() =>
  typeof route.query.redirect === 'string' ? route.query.redirect : '/'
)

onMounted(() => {
  error.value = takeLoginError()
})

function watchdog(role) {
  window.setTimeout(() => {
    // If navigation worked, this page is gone and this code doesn't matter.
    // If we're still here, unlock the buttons instead of spinning forever.
    if (busy.value === role) {
      busy.value = ''
      error.value = 'Cognito did not open. Please try again. If it repeats, restart Vite and refresh the page.'
    }
  }, 8000)
}

async function loginAs(role) {
  if (busy.value) return
  error.value = ''
  busy.value = role
  watchdog(role)

  try {
    await signIn(role, redirectTo.value)
  } catch (e) {
    error.value = e?.message || 'Unable to start Cognito sign-in.'
    busy.value = ''
  }
}

async function signup() {
  if (busy.value) return
  error.value = ''
  busy.value = 'signup'
  watchdog('signup')

  try {
    await startCustomerSignup('/')
  } catch (e) {
    error.value = e?.message || 'Unable to open Cognito.'
    busy.value = ''
  }
}
</script>

<template>
  <div class="portal-login">
    <div class="portal-glow portal-glow-one"></div>
    <div class="portal-glow portal-glow-two"></div>

    <main class="portal-login-frame">
      <section class="portal-brand-panel">
        <div class="portal-brand">
          <span class="portal-logo"><Zap :size="23" /></span>
          <div>
            <strong>TicketFlow</strong>
            <span>AWS Serverless Support</span>
          </div>
        </div>

        <div class="portal-brand-copy">
          <p class="portal-eyebrow">SECURE SUPPORT PLATFORM</p>
          <h1>One login.<br />Two purpose-built portals.</h1>
          <p>
            Customers can create and track support requests. Agents get a
            dedicated workspace to manage the complete support queue.
          </p>
        </div>

        <div class="portal-security">
          <ShieldCheck :size="16" />
          <span>
            <strong>Protected by Amazon Cognito</strong>
            <small>Your actual role is verified from Cognito after sign-in.</small>
          </span>
        </div>
      </section>

      <section class="portal-role-panel">
        <div class="portal-role-heading">
          <span class="portal-lock"><LockKeyhole :size="17" /></span>
          <div>
            <h2>Choose your portal</h2>
            <p>Use the portal assigned to your account.</p>
          </div>
        </div>

        <div v-if="error" class="portal-error">{{ error }}</div>

        <button
          class="portal-role-card customer-login-card"
          :disabled="Boolean(busy)"
          @click="loginAs('Customer')"
        >
          <span class="portal-role-icon customer-icon">
            <UserRound :size="21" />
          </span>
          <span class="portal-role-copy">
            <small>CUSTOMER PORTAL</small>
            <strong>
              {{ busy === 'Customer' ? 'Opening Cognito…' : 'Sign in as Customer' }}
            </strong>
            <em>Create tickets, track progress, and reply to support.</em>
          </span>
          <ArrowRight :size="17" />
        </button>

        <button
          class="portal-role-card agent-login-card"
          :disabled="Boolean(busy)"
          @click="loginAs('Agent')"
        >
          <span class="portal-role-icon agent-icon">
            <Headphones :size="21" />
          </span>
          <span class="portal-role-copy">
            <small>AGENT PORTAL</small>
            <strong>
              {{ busy === 'Agent' ? 'Opening Cognito…' : 'Sign in as Agent' }}
            </strong>
            <em>Manage all tickets, assignments, statuses, and replies.</em>
          </span>
          <ArrowRight :size="17" />
        </button>

        <div class="portal-divider">
          <span></span><em>New customer?</em><span></span>
        </div>

        <button
          class="portal-create-account"
          :disabled="!cognitoConfigured || Boolean(busy)"
          @click="signup"
        >
          <Ticket :size="15" />
          {{ busy === 'signup' ? 'Opening Cognito…' : 'Create customer account' }}
        </button>

        <p class="portal-signup-help">
          After Cognito opens, choose <strong>Sign up</strong> to create a new customer account.
        </p>

        <p class="portal-agent-note">
          <UsersRound :size="13" />
          Agent accounts must be added to the <strong>Agents</strong> Cognito group by an administrator.
        </p>

        <div v-if="!cognitoConfigured" class="portal-config-warning">
          Cognito environment variables are missing.
        </div>
      </section>
    </main>
  </div>
</template>
