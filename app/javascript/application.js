// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

// Disable sync buttons immediately on click to prevent double submissions
document.addEventListener("turbo:load", () => {
  initSyncButtonHandlers();
});

document.addEventListener("turbo:frame-render", (event) => {
  if (event.target.id === "action_panel") {
    initSyncButtonHandlers();
  }
});

function initSyncButtonHandlers() {
  const syncForms = document.querySelectorAll(".sync-form");

  syncForms.forEach(form => {
    form.addEventListener("submit", function() {
      // Disable all sync buttons
      document.querySelectorAll(".sync-button").forEach(button => {
        button.disabled = true;
        button.classList.add("disabled");

        // Add spinner to indicate loading
        if (button.querySelector(".spinner-border") === null) {
          const spinner = document.createElement("span");
          spinner.className = "spinner-border spinner-border-sm ms-1";
          spinner.setAttribute("role", "status");
          spinner.setAttribute("aria-hidden", "true");
          button.appendChild(spinner);
        }
      });
    });
  });
}
