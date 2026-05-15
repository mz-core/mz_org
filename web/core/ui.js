(function () {
  "use strict";

  function escapeHtml(value) {
    return String(value == null ? "" : value)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;")
      .replace(/'/g, "&#039;");
  }

  function safeText(value, fallback) {
    var output =
      value === null || value === undefined || value === ""
        ? fallback || "-"
        : value;
    return escapeHtml(output);
  }

  function renderBadge(label, variant) {
    return (
      '<span class="badge ' +
      escapeHtml(variant || "muted") +
      '"><span>' +
      safeText(label) +
      "</span></span>"
    );
  }

  function renderCard(title, description, body, className) {
    return (
      '<section class="card ' +
      escapeHtml(className || "") +
      '">' +
      (title
        ? '<div class="card-header"><h3 class="card-title">' +
          safeText(title) +
          "</h3>" +
          (description
            ? '<p class="card-desc">' + safeText(description) + "</p>"
            : "") +
          "</div>"
        : "") +
      '<div class="card-body">' +
      (body || "") +
      "</div>" +
      "</section>"
    );
  }

  function renderSectionHeader(title, description, badgeHtml) {
    return (
      '<div class="section-header"><div><h3>' +
      safeText(title) +
      "</h3>" +
      (description ? "<p>" + safeText(description) + "</p>" : "") +
      "</div>" +
      (badgeHtml || "") +
      "</div>"
    );
  }

  function renderStatCard(label, value, description, variant) {
    return (
      '<div class="stat-card ' +
      escapeHtml(variant || "") +
      '"><span>' +
      safeText(label) +
      "</span><strong>" +
      safeText(value) +
      "</strong>" +
      (description ? "<small>" + safeText(description) + "</small>" : "") +
      "</div>"
    );
  }

  function renderPermissionBadge(capability, variant) {
    var format = window.MZOrgFormat;
    var label =
      format && format.formatCapabilityLabel
        ? format.formatCapabilityLabel(capability)
        : capability;
    return renderBadge(label, variant || "muted");
  }

  function renderTechnicalDetails(title, rows) {
    rows = Array.isArray(rows) ? rows : [];
    if (!rows.length) return "";

    return (
      '<details class="technical-details"><summary>' +
      safeText(title || "Detalhes tecnicos") +
      '</summary><div class="technical-list">' +
      rows
        .map(function (row) {
          if (typeof row === "string")
            return "<code>" + safeText(row) + "</code>";
          return (
            "<div><span>" +
            safeText(row.label) +
            "</span><code>" +
            safeText(row.value) +
            "</code></div>"
          );
        })
        .join("") +
      "</div></details>"
    );
  }

  function renderLoading(title) {
    return (
      '<div class="loading"><strong>' +
      safeText(title || "Carregando") +
      "</strong></div>"
    );
  }

  function renderEmptyState(title, description) {
    return (
      '<div class="empty"><strong>' +
      safeText(title || "Nada por aqui") +
      "</strong><span>" +
      safeText(description || "") +
      "</span></div>"
    );
  }

  function renderError(message) {
    return (
      '<div class="error"><strong>Erro</strong><span>' +
      safeText(message || "Nao foi possivel carregar os dados.") +
      "</span></div>"
    );
  }

  function renderIcon(icon, fallback, className) {
    var fallbackText = escapeHtml(fallback || "?");
    return (
      '<span class="' +
      escapeHtml(className || "nav-icon-box") +
      '" aria-hidden="true">' +
      '<img class="nav-icon" src="' +
      escapeHtml(icon || "assets/icons/default.svg") +
      '" alt="" onerror="this.style.display=\'none\';this.nextElementSibling.style.display=\'grid\';" />' +
      '<span class="nav-icon-fallback">' +
      fallbackText +
      "</span>" +
      "</span>"
    );
  }

  function metricCard(icon, value, label, fallback) {
    return (
      '<div class="metric-card">' +
      renderIcon(icon, fallback || "*", "metric-icon") +
      "<strong>" +
      safeText(value) +
      "</strong><span>" +
      safeText(label) +
      "</span></div>"
    );
  }

  window.MZOrgUI = {
    escapeHtml: escapeHtml,
    safeText: safeText,
    text: safeText,
    renderBadge: renderBadge,
    badge: renderBadge,
    renderCard: renderCard,
    card: renderCard,
    renderSectionHeader: renderSectionHeader,
    sectionHeader: renderSectionHeader,
    renderStatCard: renderStatCard,
    statCard: renderStatCard,
    renderPermissionBadge: renderPermissionBadge,
    permissionBadge: renderPermissionBadge,
    rrenderTechnicalDetails: function () {
      return "";
    },
    technicalDetails: function () {
      return "";
    },
    renderLoading: renderLoading,
    loading: renderLoading,
    renderEmptyState: renderEmptyState,
    empty: renderEmptyState,
    renderError: renderError,
    errorBox: renderError,
    renderIcon: renderIcon,
    metricCard: metricCard,
  };
})();
