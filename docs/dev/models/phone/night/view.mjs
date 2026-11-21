// Reader's words for the PhoneNight chart: what the Doppelganger's phone shows.
export const title = "The Doppelganger's phone through the night (one phone, abstract server)";

const STAGE = { 0: "Your card", 1: "Window 1", 2: "Window 2", 3: "Talk" };

export const state = (v) => {
  if (!v.loaded) return "Loading";
  const st = v.snap.st;
  const base = STAGE[st];
  if (st !== 1 && st !== 2) return base;
  const turn = v.bKey ? (Array.isArray(v.bKey) ? v.bKey[1] : v.bKey[2]) : 0;
  const what = turn === 1 ? "follow-up" : st === 1 ? "look" : "turn";
  if (v.bFailed) return `${base}: ${what} "Not sent", Try again`;
  if (v.bSent === "none") return `${base}: ${what} armed`;
  return `${base}: ${what} shows Chosen`;
};

export const group = (v) => (!v.loaded ? "start" : v.snap.st === 3 ? "day" : "night");
export const colors = { start: "tan", night: "purple", day: "yellow" };

export const step = (action, from, to) => {
  switch (action) {
    case "SAdvance": return "the stage ends (timer)";
    case "SProcessStep": return "the server takes a request";
    case "FetchServe": return "the server reads /me/";
    case "FetchApply": return "a /me/ answer lands";
    case "FetchFail": return "a /me/ fetch fails";
    case "RetryFire": return "the phone retries /me/";
    case "Heal": return "the deadline fetch";
    case "EvDeliver": return "a socket event asks for /me/";
    case "EvDrop": return "a socket event is dropped";
    case "Resume": return "the app comes back";
    case "TapChoose": return "she taps Choose";
    case "TapTryAgain": return "she taps Try again";
    case "Reply": return "the answer arrives";
    case "Timeout": return "no answer in time";
    case "RwaitResume": return "Try again checks /me/";
    case "Restart": return "the app restarts";
    case "Done": return "nothing left to do";
    default: return action;
  }
};
