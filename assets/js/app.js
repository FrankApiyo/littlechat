// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import { Socket } from "phoenix"
import { LiveSocket } from "phoenix_live_view"
import topbar from "../vendor/topbar"

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")

let localStream;
async function initStream() {
  try {
    const stream = await navigator.mediaDevices.getUserMedia({ audio: true, video: true, width: "1280" })
    localStream = stream
    document.getElementById("local-video").srcObject = stream
  } catch (e) {
    console.log(e)
  }
}
let Hooks = {};
Hooks.JoinCall = {
  mounted() {
    initStream();
  },
};

var users = {}
function addUserConnection(username) {
  if (users[username] == undefined) {
    users[username] = {
      peerConnection: null
    }
  }

  return users
}

function removeUserConnection(username) {
  delete users[username]

  return users
}

Hooks.InitUser = {
  mounted() {
    addUserConnection(this.el.dataset.username)
  },

  destroyed() {
    removeUserConnection(this.el.dataset.username)
  }
}

// lv        - Our LiveView hook's `this` object
// fromUser  - The user to create the peer connection with
// offer     - Stores an SDP offer if it was passed to the function
function createPeerConnection(lv, fromUser, offer) {
  let newPeerConnection = new RTCPeerConnection({
    iceServers: [
      { urls: "stun:stun.l.google.com:19302" },
      { urls: "stun:stun.l.google.com:5349" },
      { urls: "stun:stun1.l.google.com:3478" },
      { urls: "stun:stun1.l.google.com:5349" },
      { urls: "stun:stun2.l.google.com:19302" },
      { urls: "stun:stun2.l.google.com:5349" },
      { urls: "stun:stun3.l.google.com:3478" },
      { urls: "stun:stun3.l.google.com:5349" },
      { urls: "stun:stun4.l.google.com:19302" },
      { urls: "stun:stun4.l.google.com:5349" }
    ]
  }
  )

  // Add this peer connection to our user object
  users[fromUser].peerConnection = newPeerConnection

  // Add each local track to the RTCPeerConnection
  localStream.getTracks().forEach(track => newPeerConnection.addTrack(track, localStream))

  // If creating an answer rather than the initial offer.
  if (offer !== undefined) {
    newPeerConnection.setRemoteDescription({ type: "offer", sdp: offer })
    newPeerConnection.createAnswer()
      .then((answer) => {
        newPeerConnection.setLocalDescription(answer)
        console.log("Sending this answer to the requester: ", answer)
        lv.pushEvent("new_answer", { toUser: fromUser, description: answer })
      })
      .catch((err) => console.log(err))
  }

  newPeerConnection.onicecandidate = async ({ candidate }) => {
    // fromUser is the new value of toUser because we're sending this data back
    // to the sender
    lv.PushEvent("new_ice_candidate", { toUser: fromUser, candidate })
  }

  // Don't add the `onnegotiationneeded` callback when creating and answer due to
  // a bug in Chrome's implementation of WebRTC
  if (offer == undefined) {
    newPeerConnection.onnegotiationneeded = async () => {
      try {
        newPeerConnection.createOffer()
          .then((offer) => {
            newPeerConnection.setLocalDescription(offer)
            console.log("Sending this offer to the requester: ", offer)
            lv.pushEvent("new_sdp_offer", { toUser: fromUser, description: offer })
          })
          .catch((err) => console.log(err))
      }
      catch (error) {
        console.log(error)
      }
    }
  }

  // When the data is ready to flow, add it to the correct video
  newPeerConnection.ontrack = async (event) => {
    console.log("Track received: ", event)
    document.getElementById(`video-remote-${fromUser}`).srcObject = event.streams[0]
  }

  return newPeerConnection
}

Hooks.HandleOfferRequest = {
  mounted() {
    console.log("new offer request from: ", this.el.dataset.fromUserUsername)
    let fromUser = this.el.dataset.fromUserUsername
    createPeerConnection(this, fromUser)
  }
}

let liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  hooks: Hooks,
  params: { _csrf_token: csrfToken }
})

// Show progress bar on live navigation and form submits
topbar.config({ barColors: { 0: "#29d" }, shadowColor: "rgba(0, 0, 0, .3)" })
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

