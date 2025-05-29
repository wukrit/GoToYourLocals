import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button"]

  connect() {
    // Controller is connected to the DOM
    console.log("Sync button controller connected")
  }

  submit(event) {
    // Disable all sync buttons when any sync form is submitted
    this.buttonTargets.forEach(button => {
      button.disabled = true
      button.classList.add("disabled")
      button.classList.add("sync-button-processing")

      // Add spinner to indicate loading
      if (button.querySelector(".spinner-border") === null) {
        const spinner = document.createElement("span")
        spinner.className = "spinner-border spinner-border-sm ms-1"
        spinner.setAttribute("role", "status")
        spinner.setAttribute("aria-hidden", "true")
        button.appendChild(spinner)
      }
    })
  }
}