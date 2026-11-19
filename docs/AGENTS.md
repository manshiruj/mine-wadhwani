# AI Agents — How the System Works

The inspection app (Flutter, phone/tablet/web) talks to one Node/Express backend. Inside the backend, **six AI agents run independently and at the same time**: some are triggered by events (an inspection is submitted, a health check is done, a question is asked), others run on their own timers (escalation every 15 min, risk monitoring every 10 min). Every run is recorded in an agent registry, visible in the app under **Home → AI Agents**.

| Agent | Trigger | Does | Code |
|---|---|---|---|
| Shift Agent | event: inspection submitted | NO answers → corrective actions with owner + deadline, alerts, next-shift handover | `backend/src/Services/shift_agent.js` |
| Escalation Agent | every 15 min | overdue actions → escalated to mine admin + alert | `shift_agent.js → escalateOverdue` |
| Health Manager | event: health assessment | AQM + drone PPE + smartwatch → health risk score + suggestions | `backend/src/Services/health_manager.js` |
| Risk Monitor | every 10 min + new reading | AQM/coal readings → ML grade + safety rules + 6 h forecast → LLM explanation | `backend/src/Services/risk_monitor.js` |
| Safety Assistant | on demand (chat) | answers questions using live mine data | `backend/src/Controller/ai.controller.js → chat` |
| Voice Fill Agent | on demand (voice note) | spoken notes → checklist answers | `ai.controller.js → voice_fill` |

## 1. All agents at a glance

```mermaid
flowchart LR
    subgraph App["Flutter app (phone / tablet / web)"]
        INS[Inspection checklist]
        VOICE[Voice note]
        HA[Health assessment<br/>AQM · drone PPE · smartwatch]
        CHAT[Safety Assistant chat]
        READ[Manual coal reading]
        VIEWS[Handover · Actions · Alerts<br/>Risk Monitor · AI Agents · Dashboard]
    end

    subgraph Backend["Node backend — agents run in parallel"]
        SA[Shift Agent]
        EA[Escalation Agent<br/>⏱ every 15 min]
        HM[Health Manager]
        RM[Risk Monitor<br/>⏱ every 10 min]
        AS[Safety Assistant]
        VF[Voice Fill Agent]
        REG[(Agent registry<br/>runs · status · last result)]
    end

    AQM[(aqi.in AQM device)]
    LLM{{Free LLM<br/>Groq gpt-oss-120b}}
    ML[[ML heating-grade model]]
    DB[(MongoDB)]

    INS -- submit --> SA
    VOICE --> VF
    HA --> HM
    CHAT --> AS
    READ --> RM
    AQM --> RM

    SA & HM & RM & AS & VF -.-> LLM
    RM -.-> ML
    SA & EA & HM & RM --> DB
    SA & EA & HM & RM -.-> REG
    DB --> VIEWS
    REG --> VIEWS
```

Every agent first computes the safety-critical numbers with **deterministic code** (rules, thresholds, ML); the LLM only writes explanations and suggestions and is never allowed to change a score. If the LLM is unavailable, each agent falls back to a rule-based text, so the safety logic keeps working.

## 2. Inspection → corrective actions (with deadlines) → handover

```mermaid
flowchart TD
    A[Supervisor starts inspection<br/>mine · shift · area] --> B[Optional health assessment<br/>→ Health Manager]
    B --> C[Checklist: YES / NO / NA<br/>typing or 🎤 voice fill]
    C -- every 10 s + when leaving --> D[(Auto-saved draft<br/>Pending Inspections)]
    C --> E[Compliance page: name + signature → Submit]
    E -- no network --> F[(Offline outbox on device)] -- network back --> E2
    E --> E2[Saved as completed inspection]
    E2 --> G{{Shift Agent}}
    G --> H[One corrective action per NO answer]
    H --> I[Severity = max of LLM triage and keyword safety floor]
    I --> J[Deadline: critical 4 h · high 12 h · medium 24 h · low 72 h<br/>Owner: Shift Supervisor / Mine Manager / Safety Officer ...]
    I -- critical or high --> K[Alert to mine admin 🔔]
    G --> L[Handover note for next shift<br/>summary · critical · check this shift · open actions]
    L --> M[Incoming supervisor reads + signs on screen<br/>outgoing supervisor cannot sign own handover]
    J --> N{{Escalation Agent ⏱ 15 min}}
    N -- past deadline and still open --> O[Escalated + alert to admin]
    J --> P[Owner fixes → Mark as fixed with a note]
```

**Keyword safety floor** (cannot be lowered by the AI): gas, methane, CO, H₂S, fire, explosion, collapse, slope failure, inrush, flood, electrocution, brake failure → *critical*; slope, bench, crack, berm, parapet, dust, PPE, blast, water, gradient, speed → at least *high*.

## 3. Health Manager (AQM + PPE + smartwatch)

```mermaid
flowchart LR
    A[AQM readings<br/>PM2.5 · CO · CO₂ · H₂S · CH₄ · temp · noise] --> S
    B[Drone PPE<br/>compliance % · hazard tags<br/>Roboflow model] --> S
    C[Smartwatch<br/>heart rate · SpO₂ per worker] --> S
    S[Rule engine score 0-100<br/>air 45% · PPE 25% · workers 30%<br/>worst input sets a floor] --> L{Level}
    L --> |Critical only if gas over limit or SpO₂ < 85%| X[Low / Moderate / High / Critical]
    X --> LLM{{LLM: summary, key risks,<br/>actions with owner + urgency,<br/>advice for workers, data gaps}}
    X -- High / Critical --> AL[Alert 🔔]
```

## 4. Risk Monitor (continuous spontaneous-heating monitoring)

```mermaid
flowchart TD
    T[⏱ every 10 min] --> P[Poll aqi.in device<br/>CO₂ · CO · temp · humidity · PM]
    R[Manual reading<br/>coal temp · CO · O₂ · C₂H₄] --> CUR
    P --> CUR[Current picture per zone<br/>+ last 24 h history]
    CUR --> ML[[ML model: heating grade 0-5<br/>+ probabilities + Shapley contributions]]
    CUR --> RULES[Independent safety rules<br/>coal-temp bands · C₂H₄ · CO action levels · rising trends]
    CUR --> FC[6 h forecast<br/>linear trend of CO and coal temp]
    CUR --> DQ[Data quality<br/>missing / stale sensors]
    ML & RULES --> FINAL[Final grade = max of ML grade and rule floor<br/>rules can only raise, never lower]
    FINAL & FC & DQ --> LLM{{LLM explanation<br/>facts vs inferences vs unknowns<br/>actions only from approved site procedures}}
    LLM --> CHECK[Post-checks: every rule alert reported,<br/>actions limited to procedure IDs,<br/>human review forced for High+ / low confidence]
    CHECK --> OUT[(Assessment saved)] --> V[Risk Monitor screen]
    FINAL -- grade ≥ 3 and rising --> AL[Alert 🔔]
```

Grades (coal-temperature hazard bands, Pei et al. 2024): 0 Safe < 50 °C · 1 Low 50-60 · 2 Moderate 60-100 · 3 High 100-120 · 4 Severe 120-230 · 5 Critical ≥ 230 °C.

**ML model** (`backend/ml/`): gradient-boosted trees trained on the 76 published lab rows of Guo et al. 2019 and Zhang & Chen 2025 plus synthetic rows interpolated along each coal's measured curve (with sensor noise, air dilution and random sensor dropout). Features: coal temperature, log CO, CO/CO₂, Graham's ratio (CO/ΔO₂), O₂ deficit, C₂H₄ present. Validation (each coal held out, gases only, no coal temperature): 54 % exact grade, 84 % within one grade; on the Longgu field data the grades rise in the right order. It is a screening aid built on lab data — retrain with the mine's own readings when available (`ml/.venv/bin/python ml/train.py`). See `backend/ml/README.md`.

**CO action levels** default to 100 / 190 ppm (from the Longgu field rows); they are not regulatory limits — set the mine's own values with `RISK_CO_HIGH_PPM` / `RISK_CO_SEVERE_PPM`. **Site procedures** in `backend/src/Services/site_procedures.js` are generic placeholders — replace them with the mine's approved SOPs.

## 5. Safety Assistant

```mermaid
flowchart LR
    Q[Question in Hindi / English] --> CTX[Live context for the user's mine:<br/>open actions · last handovers · recent alerts]
    CTX --> K[App knowledge: deadlines, severity rules,<br/>risk formula, grade bands]
    K --> LLM{{LLM reply in user's language}}
    LLM --> A[Plain-text answer<br/>never invents clauses or limits;<br/>gas / fire / collapse → stop work, evacuate, inform manager]
```

## 6. Configuration

`backend/.env`: `LLM_API_KEY` (free Groq key; `LLM_BASE_URL` / `LLM_MODEL` to switch provider), `ROBOFLOW_API_KEY`, `AQI_EMAIL` / `AQI_PASSWORD` / `AQI_DEVICE_SERIAL`, optional `RISK_MONITOR_INTERVAL_MIN`, `RISK_CO_HIGH_PPM`, `RISK_CO_SEVERE_PPM`. Run everything locally with `./start.sh`.
