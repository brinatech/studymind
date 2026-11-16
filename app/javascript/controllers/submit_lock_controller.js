import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "label", "spinner"]

  lock() {
    this.originalText = this.labelTarget.textContent
    this.labelTarget.textContent = "Gerando seu plano..."
    this.buttonTarget.disabled = true
    this.buttonTarget.setAttribute("aria-busy", "true")
    this.spinnerTarget.classList.remove("hidden")
  }

  unlock() {
    this.labelTarget.textContent = this.originalText || "Gerar plano"
    this.buttonTarget.disabled = false
    this.buttonTarget.removeAttribute("aria-busy")
    this.spinnerTarget.classList.add("hidden")
  }
}
