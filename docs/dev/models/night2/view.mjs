// Reader's words for the Night2 chart (only bug paths are drawn: the model is above 500 states).
export const title = "Protocol-2 game: deal to results (3 phones, one Doppelganger)";

const STAGE = {
  look: "Looking at cards",
  w1: "Doppelganger window",
  w2: "Night window",
  talk: "Talk",
  vote: "Vote",
  results: "Results",
};

export const state = (v) => {
  const base = STAGE[v.phase];
  if (v.phase !== "w1") return base;
  if (v.dCopied === "none") return `${base}: nothing copied yet`;
  if (v.dCopied !== "Robber") return `${base}: she copied the ${v.dCopied}`;
  if (v.dStep === "look") return `${base}: her repeated look is stored as her rob`;
  if (v.dStep === "followup") return `${base}: her rob is stored`;
  return `${base}: she copied the Robber`;
};

export const group = (v) =>
  ({ look: "start", w1: "night", w2: "night", talk: "day", vote: "day", results: "end" })[v.phase];
export const colors = { start: "tan", night: "purple", day: "yellow", end: "teal" };

export const step = (action, from, to) => {
  switch (action) {
    case "ChooseStep":
      if (from.phase === "w1" && from.chose.d[1] === 0) return "she looks at a player";
      if (to.retried && !from.retried) return "her phone resends the look (answer lost)";
      if (to.sentF && !from.sentF) return "she sends her rob";
      return "a phone chooses";
    case "ReadyStep":
      return "a phone taps ready";
    case "LockStep":
      return "a phone locks its vote";
    case "HostStep":
      return "the host moves on";
    case "FireStep":
      return "a timer fires";
    case "ApplyEffects":
      return null; // a timer is set or cleared after a commit: nothing the reader sees
    case "DropStep":
      return "a phone drops";
    case "Tick":
      return "its grace period runs out";
    case "ReturnStep":
      return "the phone comes back";
    case "MeRead":
    case "MeEnsure":
    case "MeDone":
      return null; // a phone reloads its game screen
    default:
      return action;
  }
};
