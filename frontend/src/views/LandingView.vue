<script setup>
import { onMounted, onBeforeUnmount, ref } from 'vue'
import { RouterLink } from 'vue-router'
import {
  ArrowRight,
  BadgeCheck,
  Box,
  Headphones,
  Layers3,
  LockKeyhole,
  MessageSquareText,
  ShieldCheck,
  Sparkles,
  Ticket,
  Zap
} from 'lucide-vue-next'
import ThreeTicketScene from '../components/ThreeTicketScene.vue'

const mounted = ref(false)
const mouseX = ref(0)
const mouseY = ref(0)

function handleMouseMove(event) {
  mouseX.value = (event.clientX / window.innerWidth - 0.5) * 2
  mouseY.value = (event.clientY / window.innerHeight - 0.5) * 2
  document.documentElement.style.setProperty('--mx', `${mouseX.value * 14}px`)
  document.documentElement.style.setProperty('--my', `${mouseY.value * 14}px`)
}

onMounted(() => {
  mounted.value = true
  window.addEventListener('mousemove', handleMouseMove, { passive: true })
})

onBeforeUnmount(() => {
  window.removeEventListener('mousemove', handleMouseMove)
})
</script>

<template>
  <div class="tf-landing" :class="{ ready: mounted }">
    <div class="tf-grid-bg"></div>
    <div class="tf-noise"></div>

    <div class="tf-orb tf-orb-a"></div>
    <div class="tf-orb tf-orb-b"></div>
    <div class="tf-orb tf-orb-c"></div>

    <header class="tf-land-nav">
      <RouterLink class="tf-brand" to="/">
        <span class="tf-brand-mark"><Zap :size="18" /></span>
        <span class="tf-brand-copy">
          <strong>TicketFlow</strong>
          <small>AWS Serverless Support</small>
        </span>
      </RouterLink>

      <div class="tf-nav-links">
        <a href="#features">Features</a>
        <a href="#architecture">Architecture</a>
        <a href="#experience">Experience</a>
      </div>

      <RouterLink class="tf-nav-login" to="/login">
        <LockKeyhole :size="14" />
        Sign in
      </RouterLink>
    </header>

    <main>
      <section class="tf-hero">
        <div class="tf-hero-copy">
          <div class="tf-pill">
            <Sparkles :size="13" />
            SERVERLESS SUPPORT, REIMAGINED
          </div>

          <h1>
            Support that feels
            <span>alive.</span>
          </h1>

          <p>
            A modern AWS ticketing experience with secure role-based access,
            real-time workflows, private attachments, and an interface built
            to feel fast, fluid and dimensional.
          </p>

          <div class="tf-hero-actions">
            <RouterLink class="tf-primary-cta" to="/login">
              Enter TicketFlow
              <ArrowRight :size="16" />
            </RouterLink>

            <a class="tf-secondary-cta" href="#features">
              Explore the experience
            </a>
          </div>

          <div class="tf-trust-row">
            <span><ShieldCheck :size="14" /> Cognito secured</span>
            <span><Zap :size="14" /> Serverless backend</span>
            <span><Box :size="14" /> Private S3 files</span>
          </div>
        </div>

        <div class="tf-hero-visual">
          <ThreeTicketScene />

          <div class="tf-float-card tf-float-one">
            <span class="tf-mini-icon green"><Ticket :size="16" /></span>
            <div>
              <small>NEW TICKET</small>
              <strong>Payment issue</strong>
              <em>High priority</em>
            </div>
          </div>

          <div class="tf-float-card tf-float-two">
            <span class="tf-mini-icon cyan"><Headphones :size="16" /></span>
            <div>
              <small>AGENT</small>
              <strong>Assigned</strong>
              <em>Aarav Shah</em>
            </div>
          </div>

          <div class="tf-float-card tf-float-three">
            <span class="tf-mini-icon amber"><MessageSquareText :size="16" /></span>
            <div>
              <small>STATUS</small>
              <strong>In Progress</strong>
              <em>Updated now</em>
            </div>
          </div>
        </div>
      </section>

      <section id="features" class="tf-section">
        <div class="tf-section-heading">
          <span>BUILT FOR BOTH SIDES</span>
          <h2>One platform. Two focused experiences.</h2>
          <p>
            Customers get a simple support journey. Agents get a powerful
            operational workspace.
          </p>
        </div>

        <div class="tf-feature-grid">
          <article class="tf-feature-card tf-tilt-a">
            <div class="tf-card-icon"><Ticket :size="20" /></div>
            <span class="tf-card-kicker">CUSTOMER PORTAL</span>
            <h3>Create. Track. Resolve.</h3>
            <p>
              Submit tickets, upload attachments, follow status changes and
              keep the conversation going with your support team.
            </p>
            <div class="tf-card-chips">
              <span>My tickets</span>
              <span>Comments</span>
              <span>S3 files</span>
            </div>
          </article>

          <article class="tf-feature-card tf-tilt-b">
            <div class="tf-card-icon cyan"><Headphones :size="20" /></div>
            <span class="tf-card-kicker cyan-text">AGENT WORKSPACE</span>
            <h3>See the full support picture.</h3>
            <p>
              Manage the queue, assign owners, change priorities, update
              statuses and respond from one focused dashboard.
            </p>
            <div class="tf-card-chips">
              <span>Queue health</span>
              <span>Assignment</span>
              <span>Activity</span>
            </div>
          </article>

          <article class="tf-feature-card tf-tilt-c">
            <div class="tf-card-icon amber"><ShieldCheck :size="20" /></div>
            <span class="tf-card-kicker amber-text">AWS SECURITY</span>
            <h3>Access based on identity.</h3>
            <p>
              Cognito authenticates users while Lambda enforces Customer
              ownership and Agent permissions on every protected request.
            </p>
            <div class="tf-card-chips">
              <span>Cognito</span>
              <span>JWT</span>
              <span>Private S3</span>
            </div>
          </article>
        </div>
      </section>

      <section id="architecture" class="tf-architecture">
        <div class="tf-arch-copy">
          <span class="tf-section-label">SERVERLESS ARCHITECTURE</span>
          <h2>Built on AWS managed services.</h2>
          <p>
            No traditional server to manage. Authentication, APIs, compute,
            data and attachments stay within a clean serverless architecture.
          </p>

          <div class="tf-stack-list">
            <div><BadgeCheck :size="15" /><span>Amazon Cognito</span><em>Identity</em></div>
            <div><BadgeCheck :size="15" /><span>API Gateway</span><em>HTTP API</em></div>
            <div><BadgeCheck :size="15" /><span>AWS Lambda</span><em>Node.js 20</em></div>
            <div><BadgeCheck :size="15" /><span>DynamoDB</span><em>Tickets + comments</em></div>
            <div><BadgeCheck :size="15" /><span>Amazon S3</span><em>Private attachments</em></div>
          </div>
        </div>

        <div class="tf-arch-model">
          <div class="tf-arch-ring ring-a"></div>
          <div class="tf-arch-ring ring-b"></div>
          <div class="tf-arch-core">
            <Layers3 :size="30" />
            <strong>TicketFlow</strong>
            <span>Serverless Core</span>
          </div>

          <div class="tf-node node-1">Vue</div>
          <div class="tf-node node-2">Cognito</div>
          <div class="tf-node node-3">Lambda</div>
          <div class="tf-node node-4">DynamoDB</div>
          <div class="tf-node node-5">S3</div>
        </div>
      </section>

      <section id="experience" class="tf-experience">
        <div class="tf-experience-card">
          <div>
            <span class="tf-section-label">READY TO ENTER</span>
            <h2>Your support workspace is one click away.</h2>
            <p>
              Choose the portal assigned to your account and continue into
              the Customer or Agent experience.
            </p>
          </div>

          <RouterLink class="tf-primary-cta" to="/login">
            Open TicketFlow
            <ArrowRight :size="16" />
          </RouterLink>
        </div>
      </section>
    </main>

    <footer class="tf-footer">
      <span>TicketFlow</span>
      <small>Vue 3 · Cognito · API Gateway · Lambda · DynamoDB · S3</small>
    </footer>
  </div>
</template>
