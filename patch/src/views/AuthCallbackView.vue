<script setup>
import { onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import { LoaderCircle, ShieldX } from 'lucide-vue-next'
import {
  clearExpectedRole,
  clearLocalAuth,
  completeSignIn,
  getExpectedRole,
  getRole,
  setLoginError,
  takePostLoginRedirect
} from '../auth/cognito'

const router = useRouter()
const error = ref('')

onMounted(async () => {
  try {
    const user = await completeSignIn()

    const expected = getExpectedRole()
    const actual = getRole(user)

    clearExpectedRole()

    if (expected && expected !== actual) {
      await clearLocalAuth()

      const message =
        expected === 'Agent'
          ? 'This account does not have Agent access. Ask an administrator to add it to the Cognito Agents group.'
          : 'This account is registered as an Agent. Please use the Agent portal.'

      setLoginError(message)
      router.replace('/login')
      return
    }

    router.replace(takePostLoginRedirect())
  } catch (e) {
    error.value = e?.message || 'Sign-in callback failed.'
  }
})
</script>

<template>
  <div class="auth-page">
    <section class="auth-card callback-card">
      <LoaderCircle v-if="!error" class="spin" :size="28" />
      <ShieldX v-else :size="28" />
      <h1>{{ error ? 'Sign-in failed' : 'Verifying your portal…' }}</h1>
      <p>
        {{ error || 'Checking your Cognito identity and role before opening TicketFlow.' }}
      </p>
      <button
        v-if="error"
        class="btn primary"
        @click="router.replace('/login')"
      >
        Back to login
      </button>
    </section>
  </div>
</template>
