// Approved site procedures the Risk Monitor may recommend. The LLM may ONLY cite these (by id).
// shortcut: generic placeholders based on common practice; replace with the mine's approved SOP texts before field use.
export const SITE_PROCEDURES = {
  surface_stockpile: [
    { id: "SP-1", text: "Increase coal and gas monitoring at the affected stockpile to every hour and record readings." },
    { id: "SP-2", text: "Inspect the stockpile face for smoke, hot spots, steam or odour; measure coal temperature at 0.5-1 m depth with a probe." },
    { id: "SP-3", text: "Compact and reshape the affected section to reduce air ingress; avoid adding fresh coal on a heating pile." },
    { id: "SP-4", text: "Dig out and spread the heated coal, cool with water spray, and dispatch or consume it first." },
    { id: "SP-5", text: "Keep fire-fighting water and extinguishers at the stockpile; keep vehicles and people clear of a smouldering face." },
    { id: "SP-6", text: "Inform the Mine Manager and Safety Officer and record the event in the stockpile inspection book." },
  ],
  underground_goaf: [
    { id: "UG-1", text: "Increase gas sampling frequency at the goaf/return (CO, O2, CO2, C2H4) and trend CO make." },
    { id: "UG-2", text: "Check seals and stoppings for leakage; reduce air leakage into the goaf." },
    { id: "UG-3", text: "Apply inertisation (nitrogen/foam/grouting) per the mine's approved plan." },
    { id: "UG-4", text: "Withdraw persons from the affected district as per the mine's emergency plan and inform the Mine Manager and DGMS as required." },
    { id: "UG-5", text: "Ventilation Officer to review the ventilation pressure balance around the goaf." },
  ],
  active_workings: [
    { id: "AW-1", text: "Trace the CO source: check conveyor belts, rollers, cables and loose coal accumulations." },
    { id: "AW-2", text: "Remove loose coal and dust accumulations; apply stone dust as required." },
    { id: "AW-3", text: "Increase gas monitoring at the face and return; inform the shift overman." },
    { id: "AW-4", text: "Withdraw persons as per the emergency plan if CO keeps rising or smoke is seen, and inform the Mine Manager." },
  ],
};
export const ENVIRONMENTS = Object.keys(SITE_PROCEDURES);
