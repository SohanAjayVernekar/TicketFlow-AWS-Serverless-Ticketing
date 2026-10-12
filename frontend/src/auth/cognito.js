import { UserManager, WebStorageStateStore } from 'oidc-client-ts'

const region = import.meta.env.VITE_AWS_REGION
const userPoolId = import.meta.env.VITE_COGNITO_USER_POOL_ID
const clientId = import.meta.env.VITE_COGNITO_CLIENT_ID
const domain = (import.meta.env.VITE_COGNITO_DOMAIN || '').replace(/\/$/, '')

export const cognitoConfigured = Boolean(region && userPoolId && clientId && domain)

const origin = window.location.origin
const authority = cognitoConfigured
  ? `https://cognito-idp.${region}.amazonaws.com/${userPoolId}`
  : ''

let manager = null

if (cognitoConfigured) {
  manager = new UserManager({
    authority,
    client_id: clientId,
    redirect_uri: `${origin}/auth/callback`,
    post_logout_redirect_uri: `${origin}/login`,
    response_type: 'code',
    scope: 'openid email profile',
    loadUserInfo: false,
    automaticSilentRenew: false,
    userStore: new WebStorageStateStore({ store: window.localStorage }),
    metadata: {
      issuer: authority,
      authorization_endpoint: `${domain}/oauth2/authorize`,
      token_endpoint: `${domain}/oauth2/token`,
      userinfo_endpoint: `${domain}/oauth2/userInfo`,
      jwks_uri: `${authority}/.well-known/jwks.json`,
      end_session_endpoint: `${domain}/logout`,
    },
  })
}

export async function signIn(expectedRole = 'Customer', redirectTo = '/') {
  if (!manager) throw new Error('Cognito is not configured.')

  sessionStorage.setItem('ticketflow.expectedRole', expectedRole)
  sessionStorage.setItem('ticketflow.redirectAfterLogin', redirectTo)

  // Important:
  // Keep this identical to the original working Cognito redirect flow.
  // Role selection is stored separately and verified AFTER Cognito returns.
  return manager.signinRedirect({
    redirectMethod: 'assign',
  })
}

export async function startCustomerSignup(redirectTo = '/') {
  // Start a valid OIDC/PKCE flow first. On Cognito's hosted page,
  // click "Sign up" to create the customer account.
  // This avoids bypassing oidc-client's stored state/PKCE verifier.
  return signIn('Customer', redirectTo)
}

export async function completeSignIn() {
  if (!manager) throw new Error('Cognito is not configured.')
  return manager.signinRedirectCallback()
}

export async function getAuthUser() {
  if (!manager) return null
  const user = await manager.getUser()
  if (!user || user.expired) return null
  return user
}

export function getGroups(user) {
  const raw = user?.profile?.['cognito:groups']
  if (Array.isArray(raw)) return raw
  if (typeof raw === 'string') return [raw]
  return []
}

export function getRole(user) {
  return getGroups(user).includes('Agents') ? 'Agent' : 'Customer'
}

export function getIdentity(user) {
  const p = user?.profile || {}
  return {
    id: String(p.sub || ''),
    name: String(p.name || p.email || 'User'),
    email: String(p.email || ''),
  }
}

export function getExpectedRole() {
  return sessionStorage.getItem('ticketflow.expectedRole') || ''
}

export function clearExpectedRole() {
  sessionStorage.removeItem('ticketflow.expectedRole')
}

export async function clearLocalAuth() {
  if (!manager) return
  await manager.removeUser()
}

export async function signOut() {
  if (!manager) return
  await manager.removeUser()

  const url = new URL(`${domain}/logout`)
  url.searchParams.set('client_id', clientId)
  url.searchParams.set('logout_uri', `${origin}/login`)
  window.location.assign(url.toString())
}

export function takePostLoginRedirect() {
  const target = sessionStorage.getItem('ticketflow.redirectAfterLogin') || '/'
  sessionStorage.removeItem('ticketflow.redirectAfterLogin')
  return target
}

export function setLoginError(message) {
  sessionStorage.setItem('ticketflow.loginError', message)
}

export function takeLoginError() {
  const message = sessionStorage.getItem('ticketflow.loginError') || ''
  sessionStorage.removeItem('ticketflow.loginError')
  return message
}
