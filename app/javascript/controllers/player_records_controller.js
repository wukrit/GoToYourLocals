import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["section", "showText", "hideText"]

  connect() {
    // Initialize the toggle state
    this.isVisible = false
  }

  toggle() {
    this.isVisible = !this.isVisible

    // Toggle the section visibility
    if (this.isVisible) {
      this.sectionTarget.style.display = "block"
      this.showTextTarget.style.display = "none"
      this.hideTextTarget.style.display = "inline"
    } else {
      this.sectionTarget.style.display = "none"
      this.showTextTarget.style.display = "inline"
      this.hideTextTarget.style.display = "none"
    }
  }
}