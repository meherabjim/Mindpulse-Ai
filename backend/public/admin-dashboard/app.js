"use strict";

const API_BASE = "/api/v1";

const views = {
  overview: {
    title: "Overview",
    subtitle: "Platform health and wellness activity"
  },
  users: {
    title: "Users",
    subtitle: "Accounts, status and recent wellness activity",
    path: "/admin/users",
    detailPath: (id) => `/admin/users/${id}`,
    searchable: true
  },
  safety: {
    title: "Safety & Risks",
    subtitle: "AI safety events and wellness risk reviews",
    path: "/admin/safety-events",
    detailPath: (id) => `/admin/safety-events/${id}`
  },
  reports: {
    title: "Reports",
    subtitle: "User-submitted operational and safety reports",
    path: "/admin/reports",
    detailPath: (id) => `/admin/reports/${id}`
  },
  contents: {
    title: "App Content",
    subtitle: "Managed multilingual application content",
    path: "/admin/contents",
    detailPath: (id) => `/admin/contents/${id}`,
    searchable: true
  },
  support: {
    title: "Support Resources",
    subtitle: "Regional crisis and support information",
    path: "/admin/support-resources",
    detailPath: (id) => `/admin/support-resources/${id}`,
    searchable: true
  },
  audit: {
    title: "Audit Logs",
    subtitle: "Recorded administrator and platform actions",
    path: "/admin/audit-logs",
    searchable: true
  },
  system: {
    title: "System Logs",
    subtitle: "Backend service and operational events",
    path: "/admin/system-logs",
    searchable: true
  }
};

const state = {
  accessToken: sessionStorage.getItem("mindpulse_admin_access") || "",
  refreshToken: sessionStorage.getItem("mindpulse_admin_refresh") || "",
  admin: null,
  currentView: "overview",
  page: 1,
  limit: 20,
  search: "",
  currentRows: [],
  modalAction: null
};

const loginView = document.querySelector("#login-view");
const appView = document.querySelector("#app-view");
const loginForm = document.querySelector("#login-form");
const loginButton = document.querySelector("#login-button");
const loginMessage = document.querySelector("#login-message");
const content = document.querySelector("#content");
const pageActions = document.querySelector("#page-actions");
const pageTitle = document.querySelector("#page-title");
const pageSubtitle = document.querySelector("#page-subtitle");
const statusBanner = document.querySelector("#status-banner");
const refreshButton = document.querySelector("#refresh-button");
const logoutButton = document.querySelector("#logout-button");
const navigation = document.querySelector("#navigation");

const dialog = document.querySelector("#action-dialog");
const dialogForm = document.querySelector("#action-form");
const dialogTitle = document.querySelector("#dialog-title");
const dialogDescription =
  document.querySelector("#dialog-description");
const dialogJson = document.querySelector("#dialog-json");
const dialogOutput = document.querySelector("#dialog-output");
const dialogSubmit = document.querySelector("#dialog-submit");

function getPayloadData(payload) {
  if (
    payload &&
    typeof payload === "object" &&
    Object.prototype.hasOwnProperty.call(payload, "data")
  ) {
    return payload.data;
  }

  return payload;
}

function firstValue(object, keys) {
  if (!object || typeof object !== "object") {
    return "";
  }

  for (const key of keys) {
    const value = object[key];

    if (typeof value === "string" && value.trim()) {
      return value;
    }
  }

  return "";
}

function extractTokens(payload) {
  const data = getPayloadData(payload) || {};
  const tokenContainer =
    data.tokens && typeof data.tokens === "object"
      ? data.tokens
      : data;

  return {
    accessToken: firstValue(tokenContainer, [
      "accessToken",
      "access_token",
      "token",
      "jwt"
    ]),
    refreshToken: firstValue(tokenContainer, [
      "refreshToken",
      "refresh_token"
    ])
  };
}

function saveTokens(accessToken, refreshToken) {
  state.accessToken = accessToken || "";
  state.refreshToken = refreshToken || "";

  if (state.accessToken) {
    sessionStorage.setItem(
      "mindpulse_admin_access",
      state.accessToken
    );
  }

  if (state.refreshToken) {
    sessionStorage.setItem(
      "mindpulse_admin_refresh",
      state.refreshToken
    );
  }
}

function clearSession() {
  state.accessToken = "";
  state.refreshToken = "";
  state.admin = null;

  sessionStorage.removeItem("mindpulse_admin_access");
  sessionStorage.removeItem("mindpulse_admin_refresh");
}

function responseMessage(payload, fallback) {
  if (
    payload &&
    typeof payload === "object" &&
    typeof payload.message === "string"
  ) {
    return payload.message;
  }

  return fallback;
}

async function parseResponse(response) {
  const text = await response.text();

  if (!text) {
    return {};
  }

  try {
    return JSON.parse(text);
  } catch {
    return {
      message: text
    };
  }
}

async function refreshSession() {
  if (!state.refreshToken) {
    return false;
  }

  const response = await fetch(`${API_BASE}/admin/auth/refresh`, {
    method: "POST",
    cache: "no-store",
    headers: {
      "Content-Type": "application/json",
      "Accept": "application/json"
    },
    body: JSON.stringify({
      refreshToken: state.refreshToken
    })
  });

  const payload = await parseResponse(response);

  if (!response.ok) {
    return false;
  }

  const tokens = extractTokens(payload);

  if (!tokens.accessToken) {
    return false;
  }

  saveTokens(
    tokens.accessToken,
    tokens.refreshToken || state.refreshToken
  );

  return true;
}

async function apiRequest(
  path,
  {
    method = "GET",
    body,
    authenticated = true,
    retry = true
  } = {}
) {
  const headers = {
    "Accept": "application/json"
  };

  if (body !== undefined) {
    headers["Content-Type"] = "application/json";
  }

  if (authenticated && state.accessToken) {
    headers.Authorization = `Bearer ${state.accessToken}`;
  }

  const response = await fetch(`${API_BASE}${path}`, {
    method,
    cache: "no-store",
    headers,
    body:
      body === undefined
        ? undefined
        : JSON.stringify(body)
  });

  const payload = await parseResponse(response);

  if (
    response.status === 401 &&
    authenticated &&
    retry &&
    await refreshSession()
  ) {
    return apiRequest(path, {
      method,
      body,
      authenticated,
      retry: false
    });
  }

  if (!response.ok) {
    const error = new Error(
      responseMessage(
        payload,
        `Request failed with HTTP ${response.status}.`
      )
    );

    error.status = response.status;
    error.payload = payload;

    throw error;
  }

  return payload;
}

function showLogin(message = "") {
  clearSession();

  appView.classList.add("is-hidden");
  loginView.classList.remove("is-hidden");

  loginMessage.textContent = message;
  document.querySelector("#password").value = "";
}

function showApp() {
  loginView.classList.add("is-hidden");
  appView.classList.remove("is-hidden");
}

function setStatus(message, type = "info") {
  statusBanner.textContent = message;
  statusBanner.className = "status-banner";

  if (type === "error") {
    statusBanner.classList.add("is-error");
  }

  if (type === "warning") {
    statusBanner.classList.add("is-warning");
  }

  statusBanner.classList.remove("is-hidden");
}

function clearStatus() {
  statusBanner.textContent = "";
  statusBanner.className = "status-banner is-hidden";
}

function setLoading(message = "Loading data…") {
  content.replaceChildren();

  const card = document.createElement("div");
  card.className = "loading-card";
  card.textContent = message;

  content.append(card);
}

function titleCase(value) {
  return String(value)
    .replace(/([a-z0-9])([A-Z])/g, "$1 $2")
    .replace(/[_-]+/g, " ")
    .replace(/\b\w/g, (character) => character.toUpperCase());
}

function primitiveDisplay(value) {
  if (value === null || value === undefined || value === "") {
    return "—";
  }

  if (typeof value === "boolean") {
    return value ? "Yes" : "No";
  }

  if (typeof value === "object") {
    return JSON.stringify(value);
  }

  return String(value);
}

function flattenLeaves(value, prefix = "", result = []) {
  if (
    value === null ||
    value === undefined ||
    typeof value !== "object"
  ) {
    result.push({
      label: prefix || "Value",
      value
    });

    return result;
  }

  if (Array.isArray(value)) {
    result.push({
      label: prefix || "Items",
      value: value.length
    });

    return result;
  }

  for (const [key, child] of Object.entries(value)) {
    const childPrefix =
      prefix
        ? `${prefix} · ${titleCase(key)}`
        : titleCase(key);

    if (
      child !== null &&
      typeof child === "object" &&
      !Array.isArray(child)
    ) {
      flattenLeaves(child, childPrefix, result);
    } else {
      result.push({
        label: childPrefix,
        value: Array.isArray(child) ? child.length : child
      });
    }
  }

  return result;
}

function findRows(payload) {
  const data = getPayloadData(payload);

  if (Array.isArray(data)) {
    return data;
  }

  if (!data || typeof data !== "object") {
    return [];
  }

  const preferredKeys = [
    "items",
    "rows",
    "users",
    "events",
    "safetyEvents",
    "safety_events",
    "reports",
    "contents",
    "resources",
    "supportResources",
    "support_resources",
    "logs",
    "auditLogs",
    "audit_logs",
    "systemLogs",
    "system_logs",
    "results"
  ];

  for (const key of preferredKeys) {
    if (Array.isArray(data[key])) {
      return data[key];
    }
  }

  for (const value of Object.values(data)) {
    if (Array.isArray(value)) {
      return value;
    }
  }

  return [];
}

function findPagination(payload) {
  const data = getPayloadData(payload);

  if (!data || typeof data !== "object") {
    return {};
  }

  return (
    data.pagination ||
    data.meta?.pagination ||
    payload.pagination ||
    {}
  );
}

function rowIdentifier(row) {
  const candidates = [
    "id",
    "userId",
    "user_id",
    "eventId",
    "event_id",
    "reportId",
    "report_id",
    "contentId",
    "content_id",
    "resourceId",
    "resource_id"
  ];

  for (const key of candidates) {
    if (
      row &&
      Object.prototype.hasOwnProperty.call(row, key)
    ) {
      return row[key];
    }
  }

  return null;
}

function prioritizedColumns(rows) {
  const priority = [
    "id",
    "name",
    "fullName",
    "full_name",
    "email",
    "role",
    "status",
    "riskLevel",
    "risk_level",
    "severity",
    "eventType",
    "event_type",
    "reportType",
    "report_type",
    "title",
    "contentKey",
    "content_key",
    "contentType",
    "content_type",
    "languageCode",
    "language_code",
    "createdAt",
    "created_at",
    "updatedAt",
    "updated_at"
  ];

  const discovered = [];

  for (const row of rows.slice(0, 20)) {
    if (!row || typeof row !== "object") {
      continue;
    }

    for (const key of Object.keys(row)) {
      if (!discovered.includes(key)) {
        discovered.push(key);
      }
    }
  }

  return [
    ...priority.filter((key) => discovered.includes(key)),
    ...discovered.filter((key) => !priority.includes(key))
  ].slice(0, 10);
}

function createButton(label, action, id, secondary = false) {
  const button = document.createElement("button");

  button.type = "button";
  button.textContent = label;
  button.dataset.action = action;

  if (id !== null && id !== undefined) {
    button.dataset.id = String(id);
  }

  if (secondary) {
    button.classList.add("button-secondary");
  }

  return button;
}

function createRowActions(view, row) {
  const wrapper = document.createElement("div");
  wrapper.className = "table-actions";

  const id = rowIdentifier(row);

  if (id === null || id === undefined) {
    wrapper.textContent = "—";
    return wrapper;
  }

  if (views[view]?.detailPath) {
    wrapper.append(
      createButton("Details", "details", id, true)
    );
  }

  if (view === "users") {
    wrapper.append(
      createButton("Status", "user-status", id)
    );
  }

  if (view === "safety") {
    wrapper.append(
      createButton("Review", "safety-review", id)
    );
  }

  if (view === "contents") {
    wrapper.append(
      createButton("Edit", "content-edit", id)
    );
  }

  if (view === "support") {
    wrapper.append(
      createButton("Edit", "support-edit", id)
    );
  }

  return wrapper;
}

function createPanel(title) {
  const panel = document.createElement("section");
  panel.className = "panel";

  const header = document.createElement("header");
  header.className = "panel-header";

  const heading = document.createElement("h2");
  heading.textContent = title;

  header.append(heading);
  panel.append(header);

  return panel;
}

function renderRawJson(parent, payload) {
  const pre = document.createElement("pre");
  pre.className = "raw-json";
  pre.textContent = JSON.stringify(payload, null, 2);

  parent.append(pre);
}

function renderOverview(summaryPayload, trendsPayload) {
  content.replaceChildren();

  const metrics =
    flattenLeaves(getPayloadData(summaryPayload))
      .filter((item) => {
        const type = typeof item.value;

        return (
          type === "number" ||
          type === "string" ||
          type === "boolean"
        );
      })
      .slice(0, 24);

  if (metrics.length) {
    const grid = document.createElement("section");
    grid.className = "metric-grid";

    for (const metric of metrics) {
      const card = document.createElement("article");
      card.className = "metric-card";

      const label = document.createElement("span");
      label.textContent = metric.label;

      const value = document.createElement("strong");
      value.textContent = primitiveDisplay(metric.value);

      card.append(label, value);
      grid.append(card);
    }

    content.append(grid);
  }

  const trendsPanel = createPanel("30-day platform trends");
  const trendsBody = document.createElement("div");
  trendsBody.className = "panel-body";

  const trendRows = findRows(trendsPayload);

  if (trendRows.length) {
    renderTableInto(
      trendsBody,
      trendRows,
      "overview",
      false
    );
  } else {
    renderRawJson(trendsBody, trendsPayload);
  }

  trendsPanel.append(trendsBody);
  content.append(trendsPanel);

  const rawPanel = createPanel("Raw dashboard summary");
  const rawBody = document.createElement("div");
  rawBody.className = "panel-body";

  renderRawJson(rawBody, summaryPayload);

  rawPanel.append(rawBody);
  content.append(rawPanel);
}

function renderTableInto(
  parent,
  rows,
  view,
  includeActions = true
) {
  if (!rows.length) {
    const empty = document.createElement("div");
    empty.className = "empty-card";
    empty.textContent = "No records were returned.";

    parent.append(empty);
    return;
  }

  const columns = prioritizedColumns(rows);
  const scroll = document.createElement("div");
  scroll.className = "table-scroll";

  const table = document.createElement("table");
  table.className = "data-table";

  const thead = document.createElement("thead");
  const headerRow = document.createElement("tr");

  for (const column of columns) {
    const th = document.createElement("th");
    th.textContent = titleCase(column);
    headerRow.append(th);
  }

  if (includeActions) {
    const actionHeader = document.createElement("th");
    actionHeader.textContent = "Actions";
    headerRow.append(actionHeader);
  }

  thead.append(headerRow);
  table.append(thead);

  const tbody = document.createElement("tbody");

  for (const row of rows) {
    const tr = document.createElement("tr");

    for (const column of columns) {
      const td = document.createElement("td");
      td.textContent = primitiveDisplay(row[column]);
      tr.append(td);
    }

    if (includeActions) {
      const td = document.createElement("td");
      td.append(createRowActions(view, row));
      tr.append(td);
    }

    tbody.append(tr);
  }

  table.append(tbody);
  scroll.append(table);
  parent.append(scroll);

  // MINDPULSE TABLE START POSITION FIX V5
  // Every newly rendered table begins at its first column.
  scroll.scrollLeft = 0;

  window.requestAnimationFrame(() => {
    scroll.scrollLeft = 0;
  });
}

function renderList(payload, view) {
  content.replaceChildren();

  const rows = findRows(payload);
  const pagination = findPagination(payload);
  state.currentRows = rows;

  const panel = createPanel(views[view].title);
  const body = document.createElement("div");
  body.className = "panel-body";

  if (views[view].searchable) {
    const toolbar = document.createElement("form");
    toolbar.className = "list-toolbar";
    toolbar.id = "search-form";

    const searchInput = document.createElement("input");
    searchInput.type = "search";
    searchInput.name = "search";
    searchInput.placeholder = "Search records";
    searchInput.value = state.search;

    const searchButton = document.createElement("button");
    searchButton.type = "submit";
    searchButton.textContent = "Search";

    toolbar.append(searchInput, searchButton);
    body.append(toolbar);
  }

  renderTableInto(body, rows, view, true);

  panel.append(body);

  const paginationBar = document.createElement("footer");
  paginationBar.className = "pagination";

  const page =
    Number(
      pagination.page ||
      pagination.currentPage ||
      pagination.current_page ||
      state.page
    ) || state.page;

  const totalPages =
    Number(
      pagination.totalPages ||
      pagination.total_pages ||
      0
    ) || 0;

  const total =
    Number(
      pagination.total ||
      pagination.totalItems ||
      pagination.total_items ||
      rows.length
    ) || rows.length;

  const description = document.createElement("span");

  description.textContent =
    totalPages > 0
      ? `Page ${page} of ${totalPages} · ${total} records`
      : `Page ${page} · ${total} records`;

  const previousButton =
    createButton("Previous", "previous-page", null, true);

  previousButton.disabled = page <= 1;

  const nextButton =
    createButton("Next", "next-page", null, true);

  if (totalPages > 0) {
    nextButton.disabled = page >= totalPages;
  } else {
    nextButton.disabled = rows.length < state.limit;
  }

  paginationBar.append(
    description,
    previousButton,
    nextButton
  );

  panel.append(paginationBar);
  content.append(panel);

  const rawPanel = createPanel("Raw API response");
  const rawBody = document.createElement("div");
  rawBody.className = "panel-body";

  renderRawJson(rawBody, payload);
  rawPanel.append(rawBody);
  content.append(rawPanel);

  const searchForm = document.querySelector("#search-form");

  if (searchForm) {
    searchForm.addEventListener("submit", (event) => {
      event.preventDefault();

      state.search =
        new FormData(searchForm)
          .get("search")
          ?.toString()
          .trim() || "";

      state.page = 1;
      loadCurrentView();
    });
  }
}

function updatePageActions(view) {
  pageActions.replaceChildren();

  if (view === "overview") {
    pageActions.append(
      createButton(
        "Create announcement",
        "announcement",
        null
      )
    );
  }

  if (view === "contents") {
    pageActions.append(
      createButton(
        "Create app content",
        "content-create",
        null
      )
    );
  }

  if (view === "support") {
    pageActions.append(
      createButton(
        "Create support resource",
        "support-create",
        null
      )
    );
  }
}

async function loadOverview() {
  const [summary, trends] = await Promise.all([
    apiRequest("/admin/dashboard/summary"),
    apiRequest("/admin/dashboard/trends?days=30")
  ]);

  renderOverview(summary, trends);
}

function buildListPath(view) {
  const config = views[view];
  const parameters = new URLSearchParams();

  parameters.set("page", String(state.page));
  parameters.set("limit", String(state.limit));

  if (config.searchable && state.search) {
    parameters.set("search", state.search);
  }

  return `${config.path}?${parameters.toString()}`;
}

async function loadCurrentView() {
  const view = state.currentView;
  const config = views[view];

  clearStatus();
  updatePageActions(view);

  pageTitle.textContent = config.title;
  pageSubtitle.textContent = config.subtitle;

  setLoading(`Loading ${config.title.toLowerCase()}…`);

  try {
    if (view === "overview") {
      await loadOverview();
    } else {
      const payload =
        await apiRequest(buildListPath(view));

      renderList(payload, view);
    }
  } catch (error) {
    if (error.status === 401 || error.status === 403) {
      showLogin(
        "Your administrator session expired or lacks permission."
      );

      return;
    }

    content.replaceChildren();

    const card = document.createElement("div");
    card.className = "empty-card";
    card.textContent = error.message;

    content.append(card);
    setStatus(error.message, "error");
  }
}

function setActiveNavigation(view) {
  for (const button of navigation.querySelectorAll("[data-view]")) {
    button.classList.toggle(
      "is-active",
      button.dataset.view === view
    );
  }
}

function selectView(view) {
  if (!views[view]) {
    return;
  }

  state.currentView = view;
  state.page = 1;
  state.search = "";

  setActiveNavigation(view);
  loadCurrentView();
}

function currentRow(id) {
  return state.currentRows.find(
    (row) => String(rowIdentifier(row)) === String(id)
  );
}

function openDialog({
  title,
  description,
  method,
  path,
  payload,
  submitLabel = "Submit"
}) {
  state.modalAction = {
    method,
    path
  };

  dialogJson.readOnly = false;
  dialogJson.classList.remove("is-read-only");

  dialogTitle.textContent = title;
  dialogDescription.textContent = description;
  dialogJson.value = JSON.stringify(payload, null, 2);
  dialogOutput.textContent = "";
  dialogOutput.classList.add("is-hidden");
  dialogSubmit.textContent = submitLabel;
  dialogSubmit.disabled = false;

  if (typeof dialog.showModal === "function") {
    dialog.showModal();
  } else {
    dialog.setAttribute("open", "");
  }
}

function openReadOnly(title, payload) {
  state.modalAction = null;

  dialogJson.readOnly = true;
  dialogJson.classList.add("is-read-only");

  dialogTitle.textContent = title;
  dialogDescription.textContent =
    "This is the complete response returned by the backend.";

  dialogJson.value = JSON.stringify(payload, null, 2);
  dialogOutput.classList.add("is-hidden");
  dialogSubmit.classList.add("is-hidden");

  if (typeof dialog.showModal === "function") {
    dialog.showModal();
  } else {
    dialog.setAttribute("open", "");
  }
}

function closeDialog() {
  state.modalAction = null;

  dialogJson.readOnly = false;
  dialogJson.classList.remove("is-read-only");

  dialogSubmit.classList.remove("is-hidden");

  if (typeof dialog.close === "function") {
    dialog.close();
  } else {
    dialog.removeAttribute("open");
  }
}

function pick(object, keys) {
  const result = {};

  for (const key of keys) {
    if (
      object &&
      Object.prototype.hasOwnProperty.call(object, key)
    ) {
      result[key] = object[key];
    }
  }

  return result;
}

function contentPayload(row = {}) {
  return {
    ...pick(row, [
      "contentKey",
      "contentType",
      "languageCode",
      "title",
      "content",
      "version",
      "isActive",
      "publishedAt"
    ]),
    contentKey: row.contentKey || row.content_key || "",
    contentType: row.contentType || row.content_type || "",
    languageCode:
      row.languageCode || row.language_code || "en",
    title: row.title || "",
    content: row.content || "",
    version: row.version || "1.0",
    isActive:
      row.isActive ?? row.is_active ?? true,
    publishedAt:
      row.publishedAt || row.published_at || null
  };
}

function supportPayload(row = {}) {
  return {
    countryCode:
      row.countryCode || row.country_code || "",
    regionName:
      row.regionName || row.region_name || "",
    resourceType:
      row.resourceType || row.resource_type || "",
    name: row.name || "",
    phone: row.phone || null,
    email: row.email || null,
    address: row.address || null,
    websiteUrl:
      row.websiteUrl || row.website_url || null,
    languages: row.languages || [],
    isActive:
      row.isActive ?? row.is_active ?? true,
    displayOrder:
      row.displayOrder ?? row.display_order ?? 0
  };
}

async function showDetails(id) {
  const config = views[state.currentView];

  if (!config?.detailPath) {
    return;
  }

  try {
    const payload =
      await apiRequest(config.detailPath(id));

    openReadOnly(
      `${config.title} details`,
      payload
    );
  } catch (error) {
    setStatus(error.message, "error");
  }
}

function handleAction(action, id) {
  const row = id ? currentRow(id) : null;

  if (action === "details") {
    showDetails(id);
    return;
  }

  if (action === "previous-page") {
    state.page = Math.max(1, state.page - 1);
    loadCurrentView();
    return;
  }

  if (action === "next-page") {
    state.page += 1;
    loadCurrentView();
    return;
  }

  if (action === "announcement") {
    openDialog({
      title: "Create announcement",
      description:
        "Send a platform announcement using the admin API.",
      method: "POST",
      path: "/admin/announcements",
      payload: {
        title: "",
        content: "",
        priority: "normal"
      },
      submitLabel: "Create announcement"
    });

    return;
  }

  if (action === "user-status") {
    openDialog({
      title: "Update user status",
      description:
        "Enter a backend-supported status and an audit reason.",
      method: "PATCH",
      path: `/admin/users/${id}/status`,
      payload: {
        status: row?.status || "",
        reason: ""
      },
      submitLabel: "Update status"
    });

    return;
  }

  if (action === "safety-review") {
    openDialog({
      title: "Review safety event",
      description:
        "Record the event review status and an optional note.",
      method: "PATCH",
      path: `/admin/safety-events/${id}/review`,
      payload: {
        reviewStatus:
          row?.reviewStatus ||
          row?.review_status ||
          "",
        note: ""
      },
      submitLabel: "Save review"
    });

    return;
  }

  if (action === "content-create") {
    openDialog({
      title: "Create app content",
      description:
        "Create a managed multilingual content record.",
      method: "POST",
      path: "/admin/contents",
      payload: contentPayload(),
      submitLabel: "Create content"
    });

    return;
  }

  if (action === "content-edit") {
    openDialog({
      title: "Update app content",
      description:
        "Only include fields supported by the backend validator.",
      method: "PATCH",
      path: `/admin/contents/${id}`,
      payload: contentPayload(row),
      submitLabel: "Update content"
    });

    return;
  }

  if (action === "support-create") {
    openDialog({
      title: "Create support resource",
      description:
        "Create a regional support or crisis resource.",
      method: "POST",
      path: "/admin/support-resources",
      payload: supportPayload(),
      submitLabel: "Create resource"
    });

    return;
  }

  if (action === "support-edit") {
    openDialog({
      title: "Update support resource",
      description:
        "Only include fields supported by the backend validator.",
      method: "PATCH",
      path: `/admin/support-resources/${id}`,
      payload: supportPayload(row),
      submitLabel: "Update resource"
    });
  }
}

async function loadAdminProfile() {
  const payload = await apiRequest("/admin/auth/me");
  const data = getPayloadData(payload) || {};

  state.admin =
    data.admin ||
    data.user ||
    data.profile ||
    data;

  const name =
    state.admin.name ||
    state.admin.fullName ||
    state.admin.full_name ||
    state.admin.email ||
    "Administrator";

  const email = state.admin.email || "";
  const role =
    state.admin.role ||
    state.admin.roleName ||
    state.admin.role_name ||
    "Administrator";

  document.querySelector("#admin-name").textContent = name;
  document.querySelector("#admin-email").textContent = email;
  document.querySelector("#admin-role").textContent =
    titleCase(role);
}

async function bootDashboard() {
  try {
    await loadAdminProfile();
    showApp();
    await loadCurrentView();
  } catch (error) {
    showLogin(
      error.status === 401
        ? "Please sign in to continue."
        : error.message
    );
  }
}

loginForm.addEventListener("submit", async (event) => {
  event.preventDefault();

  loginMessage.textContent = "";
  loginButton.disabled = true;
  loginButton.textContent = "Signing in…";

  const formData = new FormData(loginForm);

  try {
    const payload =
      await apiRequest(
        "/admin/auth/login",
        {
          method: "POST",
          authenticated: false,
          retry: false,
          body: {
            email:
              formData.get("email")?.toString().trim() || "",
            password:
              formData.get("password")?.toString() || ""
          }
        }
      );

    const tokens = extractTokens(payload);

    if (!tokens.accessToken) {
      throw new Error(
        "Login succeeded but no access token was returned."
      );
    }

    saveTokens(tokens.accessToken, tokens.refreshToken);
    await bootDashboard();
  } catch (error) {
    loginMessage.textContent = error.message;
  } finally {
    loginButton.disabled = false;
    loginButton.textContent = "Sign in securely";
  }
});

navigation.addEventListener("click", (event) => {
  const button = event.target.closest("[data-view]");

  if (button) {
    selectView(button.dataset.view);
  }
});

content.addEventListener("click", (event) => {
  const button = event.target.closest("[data-action]");

  if (button) {
    handleAction(
      button.dataset.action,
      button.dataset.id || null
    );
  }
});

pageActions.addEventListener("click", (event) => {
  const button = event.target.closest("[data-action]");

  if (button) {
    handleAction(
      button.dataset.action,
      button.dataset.id || null
    );
  }
});

refreshButton.addEventListener("click", () => {
  loadCurrentView();
});

logoutButton.addEventListener("click", async () => {
  try {
    if (state.refreshToken) {
      await apiRequest(
        "/admin/auth/logout",
        {
          method: "POST",
          body: {
            refreshToken: state.refreshToken
          }
        }
      );
    }
  } catch {
    // Local session is cleared even if server logout fails.
  }

  showLogin("You have signed out.");
});

document
  .querySelector("#dialog-close")
  .addEventListener("click", closeDialog);

document
  .querySelector("#dialog-cancel")
  .addEventListener("click", closeDialog);

dialogForm.addEventListener("submit", async (event) => {
  event.preventDefault();

  if (!state.modalAction) {
    closeDialog();
    return;
  }

  let payload;

  try {
    payload = JSON.parse(dialogJson.value);
  } catch {
    dialogOutput.textContent =
      "The request body is not valid JSON.";

    dialogOutput.classList.remove("is-hidden");
    return;
  }

  dialogSubmit.disabled = true;
  dialogSubmit.textContent = "Submitting…";

  try {
    const result =
      await apiRequest(
        state.modalAction.path,
        {
          method: state.modalAction.method,
          body: payload
        }
      );

    dialogOutput.textContent =
      JSON.stringify(result, null, 2);

    dialogOutput.classList.remove("is-hidden");

    setStatus(
      responseMessage(
        result,
        "Administrative action completed successfully."
      )
    );

    window.setTimeout(() => {
      closeDialog();
      loadCurrentView();
    }, 800);
  } catch (error) {
    dialogOutput.textContent =
      JSON.stringify(
        error.payload || {
          message: error.message
        },
        null,
        2
      );

    dialogOutput.classList.remove("is-hidden");
  } finally {
    dialogSubmit.disabled = false;
    dialogSubmit.textContent = "Submit";
  }
});

if (state.accessToken) {
  bootDashboard();
} else {
  showLogin();
}
// BEGIN MINDPULSE ADMIN UI V2
(() => {
  "use strict";

  const themeButton =
    document.querySelector("#theme-toggle");

  const pageTitleElement =
    document.querySelector("#page-title");

  const contentElement =
    document.querySelector("#content");

  function applyTheme(theme) {
    const normalized =
      theme === "dark" ? "dark" : "light";

    document.documentElement.dataset.theme =
      normalized;

    localStorage.setItem(
      "mindpulse_admin_theme",
      normalized
    );

    if (themeButton) {
      const isDark = normalized === "dark";

      themeButton.textContent =
        isDark ? "Light mode" : "Dark mode";

      themeButton.setAttribute(
        "aria-pressed",
        String(isDark)
      );
    }
  }

  const savedTheme =
    localStorage.getItem("mindpulse_admin_theme");

  const preferredTheme =
    window.matchMedia &&
    window.matchMedia("(prefers-color-scheme: dark)")
      .matches
      ? "dark"
      : "light";

  applyTheme(savedTheme || preferredTheme);

  themeButton?.addEventListener("click", () => {
    const nextTheme =
      document.documentElement.dataset.theme === "dark"
        ? "light"
        : "dark";

    applyTheme(nextTheme);
  });

  function metricAppearance(label) {
    const value = label.toLowerCase();

    if (
      value.includes("risk") ||
      value.includes("critical") ||
      value.includes("safety") ||
      value.includes("report")
    ) {
      return {
        tone: "danger",
        icon: "!"
      };
    }

    if (
      value.includes("pending") ||
      value.includes("burnout") ||
      value.includes("warning")
    ) {
      return {
        tone: "warning",
        icon: "△"
      };
    }

    if (
      value.includes("active") ||
      value.includes("complete") ||
      value.includes("healthy") ||
      value.includes("success")
    ) {
      return {
        tone: "success",
        icon: "✓"
      };
    }

    if (
      value.includes("user") ||
      value.includes("member")
    ) {
      return {
        tone: "default",
        icon: "◎"
      };
    }

    if (
      value.includes("scan") ||
      value.includes("checkin")
    ) {
      return {
        tone: "default",
        icon: "◇"
      };
    }

    if (
      value.includes("message") ||
      value.includes("conversation")
    ) {
      return {
        tone: "default",
        icon: "◌"
      };
    }

    return {
      tone: "default",
      icon: "↗"
    };
  }

  function enhanceMetricCards() {
    const cards =
      document.querySelectorAll(
        ".metric-card:not([data-ui-v2])"
      );

    cards.forEach((card) => {
      const label =
        card.querySelector("span")
          ?.textContent
          ?.trim() || "";

      const appearance =
        metricAppearance(label);

      card.dataset.uiV2 = "true";
      card.dataset.tone = appearance.tone;
      card.dataset.icon = appearance.icon;
    });
  }

  function enhanceRawPanels() {
    document
      .querySelectorAll(".panel:not([data-raw-checked])")
      .forEach((panel) => {
        panel.dataset.rawChecked = "true";

        const heading =
          panel.querySelector(".panel-header h2");

        const title =
          heading?.textContent?.trim().toLowerCase() || "";

        if (!title.startsWith("raw ")) {
          return;
        }

        panel.classList.add("raw-panel");

        const header =
          panel.querySelector(".panel-header");

        if (!header) {
          return;
        }

        header.tabIndex = 0;
        header.setAttribute("role", "button");
        header.setAttribute(
          "aria-expanded",
          "false"
        );

        const toggle = () => {
          const isOpen =
            panel.classList.toggle("is-open");

          header.setAttribute(
            "aria-expanded",
            String(isOpen)
          );
        };

        header.addEventListener("click", toggle);

        header.addEventListener(
          "keydown",
          (event) => {
            if (
              event.key === "Enter" ||
              event.key === " "
            ) {
              event.preventDefault();
              toggle();
            }
          }
        );
      });
  }

  function addOverviewHero() {
    if (
      pageTitleElement?.textContent?.trim() !==
      "Overview"
    ) {
      return;
    }

    if (
      document.querySelector(".overview-hero") ||
      !document.querySelector(".metric-grid")
    ) {
      return;
    }

    const hero =
      document.createElement("section");

    hero.className = "overview-hero";

    const copy =
      document.createElement("div");

    const heading =
      document.createElement("h2");

    heading.textContent =
      "MindPulse operations overview";

    const paragraph =
      document.createElement("p");

    paragraph.textContent =
      "Monitor platform activity, user wellbeing, safety events and operational health from one secure workspace.";

    copy.append(heading, paragraph);

    const meta =
      document.createElement("div");

    meta.className = "overview-hero-meta";

    const status =
      document.createElement("strong");

    status.textContent = "Platform services online";

    const updated =
      document.createElement("span");

    updated.textContent =
      `Updated ${new Date().toLocaleTimeString(
        [],
        {
          hour: "2-digit",
          minute: "2-digit"
        }
      )}`;

    meta.append(status, updated);
    hero.append(copy, meta);

    contentElement?.prepend(hero);
  }

  function addSearchHint() {
    const input =
      document.querySelector(
        '#search-form input[type="search"]'
      );

    if (
      input &&
      !input.dataset.hintAdded
    ) {
      input.dataset.hintAdded = "true";
      input.placeholder =
        "Search records — press / to focus";
    }
  }

  function enhanceDashboard() {
    enhanceMetricCards();
    enhanceRawPanels();
    addOverviewHero();
    addSearchHint();
  }

  const observer =
    new MutationObserver(() => {
      enhanceDashboard();
    });

  observer.observe(
    document.body,
    {
      childList: true,
      subtree: true
    }
  );

  document.addEventListener(
    "keydown",
    (event) => {
      if (
        event.key === "/" &&
        !["INPUT", "TEXTAREA"].includes(
          document.activeElement?.tagName
        )
      ) {
        const search =
          document.querySelector(
            '#search-form input[type="search"]'
          );

        if (search) {
          event.preventDefault();
          search.focus();
        }
      }
    }
  );

  enhanceDashboard();
})();
// END MINDPULSE ADMIN UI V2
// BEGIN MINDPULSE TABLE READABILITY V4
(() => {
  "use strict";

  const visibleColumns = {
    "Users": [
      "ID",
      "FULL NAME",
      "EMAIL",
      "ACCOUNT STATUS",
      "ONBOARDING COMPLETED",
      "EMAIL VERIFIED",
      "LAST LOGIN AT",
      "ACTIONS"
    ],

    "Safety & Risks": [
      "ID",
      "EVENT TYPE",
      "CREATED AT",
      "USER",
      "SEVERITY LEVEL",
      "REDACTED EXCERPT",
      "ACTION TAKEN",
      "ACTIONS"
    ],

    "Reports": [
      "ID",
      "STATUS",
      "REPORT TYPE",
      "CREATED AT",
      "USER",
      "SUMMARY",
      "GENERATED BY",
      "ACTIONS"
    ],

    "App Content": [
      "ID",
      "CONTENT KEY",
      "CONTENT TYPE",
      "LANGUAGE CODE",
      "TITLE",
      "VERSION",
      "IS ACTIVE",
      "UPDATED AT",
      "ACTIONS"
    ],

    "Support Resources": [
      "ID",
      "COUNTRY CODE",
      "REGION NAME",
      "RESOURCE TYPE",
      "NAME",
      "PHONE",
      "IS ACTIVE",
      "ACTIONS"
    ],

    "Audit Logs": [
      "ID",
      "CREATED AT",
      "ACTOR TYPE",
      "ACTOR",
      "ACTION",
      "ENTITY TYPE",
      "ENTITY ID",
      "METADATA"
    ],

    "System Logs": [
      "ID",
      "CREATED AT",
      "LOG LEVEL",
      "SERVICE NAME",
      "EVENT CODE",
      "MESSAGE"
    ]
  };

  function normalize(value) {
    return String(value || "")
      .replace(/\s+/g, " ")
      .trim()
      .toUpperCase();
  }

  function isDateColumn(label) {
    return (
      label.includes("DATE") ||
      label.endsWith(" AT") ||
      label.includes("LOGIN AT") ||
      label.includes("UPDATED AT") ||
      label.includes("CREATED AT")
    );
  }

  function formatDate(value) {
    const parsed = new Date(value);

    if (Number.isNaN(parsed.getTime())) {
      return value;
    }

    return parsed.toLocaleString(
      [],
      {
        year: "numeric",
        month: "short",
        day: "2-digit",
        hour: "2-digit",
        minute: "2-digit"
      }
    );
  }

  function compactObject(value) {
    if (Array.isArray(value)) {
      if (value.length === 0) {
        return "None";
      }

      if (
        value.every(
          (item) => typeof item === "string"
        )
      ) {
        const firstItems =
          value.slice(0, 3).join(", ");

        if (value.length > 3) {
          return (
            firstItems +
            " +" +
            String(value.length - 3)
          );
        }

        return firstItems;
      }

      return (
        String(value.length) +
        (value.length === 1 ? " item" : " items")
      );
    }

    if (!value || typeof value !== "object") {
      return String(value || "");
    }

    const name =
      value.fullName ||
      value.full_name ||
      value.name ||
      value.title ||
      "";

    const email =
      value.email || "";

    const id =
      value.id ??
      value.userId ??
      value.user_id ??
      value.adminUserId ??
      value.admin_user_id ??
      "";

    const parts = [];

    if (name) {
      parts.push(String(name));
    }

    if (email && email !== name) {
      parts.push(String(email));
    }

    if (id !== "") {
      parts.push("#" + String(id));
    }

    if (parts.length > 0) {
      return parts.join(" · ");
    }

    const keys = Object.keys(value);

    return (
      String(keys.length) +
      (keys.length === 1 ? " field" : " fields")
    );
  }

  function compactCellText(raw, label) {
    const text =
      String(raw || "")
        .replace(/\s+/g, " ")
        .trim();

    if (!text || text === "—") {
      return "—";
    }

    if (
      text.startsWith("{") ||
      text.startsWith("[")
    ) {
      try {
        return compactObject(JSON.parse(text));
      } catch {
        // Use normal text below.
      }
    }

    if (isDateColumn(label)) {
      return formatDate(text);
    }

    if (text.length > 110) {
      return text.slice(0, 107) + "...";
    }

    return text;
  }

  function badgeTone(value) {
    const text =
      String(value || "").toLowerCase();

    if (
      text.includes("critical") ||
      text.includes("high") ||
      text.includes("blocked") ||
      text.includes("suspended") ||
      text.includes("failed")
    ) {
      return "danger";
    }

    if (
      text.includes("pending") ||
      text.includes("medium") ||
      text.includes("review") ||
      text.includes("warning")
    ) {
      return "warning";
    }

    if (
      text.includes("active") ||
      text.includes("complete") ||
      text.includes("verified") ||
      text.includes("success") ||
      text === "yes" ||
      text === "low"
    ) {
      return "success";
    }

    return "neutral";
  }

  function isBadgeColumn(label) {
    return (
      label.includes("STATUS") ||
      label.includes("SEVERITY") ||
      label.includes("RISK") ||
      label.includes("VERIFIED") ||
      label.includes("COMPLETED") ||
      label === "IS ACTIVE"
    );
  }

  function enhanceCell(cell, label) {
    if (label === "ACTIONS") {
      return;
    }

    const original =
      cell.textContent.trim();

    if (!original) {
      return;
    }

    cell.title = original;

    const compact =
      compactCellText(original, label);

    if (label === "ID") {
      cell.classList.add("readable-id");
    }

    if (label.includes("EMAIL")) {
      cell.classList.add("readable-email");
    }

    if (isDateColumn(label)) {
      cell.classList.add("readable-date");
    }

    if (
      label.includes("SUMMARY") ||
      label.includes("EXCERPT") ||
      label.includes("MESSAGE") ||
      label.includes("ACTION TAKEN") ||
      label.includes("METADATA")
    ) {
      cell.classList.add("readable-wide");
    }

    if (isBadgeColumn(label)) {
      const badge =
        document.createElement("span");

      badge.className =
        "table-badge table-badge-" +
        badgeTone(compact);

      badge.textContent = compact;

      cell.replaceChildren(badge);
    } else {
      cell.textContent = compact;
    }
  }

  function enhanceTable(table) {
    if (table.dataset.readabilityV4 === "true") {
      return;
    }

    const pageTitle =
      document
        .querySelector("#page-title")
        ?.textContent
        ?.trim() || "";

    const allowed =
      visibleColumns[pageTitle];

    const headers =
      Array.from(
        table.querySelectorAll("thead th")
      );

    const rows =
      Array.from(
        table.querySelectorAll("tbody tr")
      );

    headers.forEach((header, index) => {
      const label =
        normalize(header.textContent);

      const shouldHide =
        Array.isArray(allowed) &&
        !allowed.includes(label);

      if (shouldHide) {
        header.hidden = true;

        rows.forEach((row) => {
          const cell = row.children[index];

          if (cell) {
            cell.hidden = true;
          }
        });

        return;
      }

      rows.forEach((row) => {
        const cell = row.children[index];

        if (cell) {
          enhanceCell(cell, label);
        }
      });
    });

    table.dataset.readabilityV4 = "true";
  }

  function enhanceDashboardTables() {
    document
      .querySelectorAll(".data-table")
      .forEach(enhanceTable);
  }

  const topbarLogout =
    document.querySelector(
      "#topbar-logout-button"
    );

  topbarLogout?.addEventListener(
    "click",
    () => {
      document
        .querySelector("#logout-button")
        ?.click();
    }
  );

  const observer =
    new MutationObserver(() => {
      enhanceDashboardTables();
    });

  observer.observe(
    document.querySelector("#content") ||
      document.body,
    {
      childList: true,
      subtree: true
    }
  );

  enhanceDashboardTables();
})();
// END MINDPULSE TABLE READABILITY V4
// BEGIN MINDPULSE FACTORY RESET UI
(() => {
  "use strict";

  const previewEndpoint =
    "/api/v1/admin/maintenance/factory-reset/preview";

  const resetEndpoint =
    "/api/v1/admin/maintenance/factory-reset";

  let currentPreview = null;
  // BEGIN FACTORY RESET EXISTING AUTH BRIDGE V3

  /*
    Factory Reset uses the same authenticated request helper
    as every other Admin Dashboard feature.

    apiRequest() already:
    - uses state.accessToken
    - refreshes an expired access token
    - saves rotated tokens
    - retries once after HTTP 401
  */

  async function factoryRequest(
    method,
    endpoint,
    body
  ) {
    const requestPath =
      endpoint.startsWith(API_BASE)
        ? endpoint.slice(API_BASE.length)
        : endpoint;

    const payload =
      await apiRequest(
        requestPath,
        {
          method,
          body,
          authenticated: true,
          retry: true
        }
      );

    return getPayloadData(payload) || {};
  }

  // END FACTORY RESET EXISTING AUTH BRIDGE V3

  function number(value) {
    return new Intl.NumberFormat().format(
      Number(value || 0)
    );
  }

  function setStatus(
    message,
    type = "neutral"
  ) {
    const element =
      document.querySelector(
        "#factory-reset-status"
      );

    if (!element) {
      return;
    }

    element.className =
      `factory-reset-status factory-reset-status-${type}`;

    element.textContent = message;
  }

  function createTableRow(item) {
    const row =
      document.createElement("div");

    row.className =
      "factory-table-row";

    const name =
      document.createElement("span");

    name.textContent =
      String(item.table || "");

    const count =
      document.createElement("strong");

    count.textContent =
      number(item.rows);

    row.append(name, count);

    return row;
  }

  function renderPreview(preview) {
    currentPreview = preview;

    const total =
      document.querySelector(
        "#factory-total-rows"
      );

    const resetList =
      document.querySelector(
        "#factory-reset-tables"
      );

    const protectedList =
      document.querySelector(
        "#factory-protected-tables"
      );

    const resetButton =
      document.querySelector(
        "#factory-open-dialog"
      );

    if (
      !total ||
      !resetList ||
      !protectedList ||
      !resetButton
    ) {
      return;
    }

    total.textContent =
      number(preview.totalRows);

    resetList.replaceChildren();

    (preview.resetTables || [])
      .forEach((item) => {
        resetList.append(
          createTableRow(item)
        );
      });

    protectedList.replaceChildren();

    (preview.preservedTables || [])
      .forEach((item) => {
        protectedList.append(
          createTableRow(item)
        );
      });

    resetButton.disabled = false;

    setStatus(
      "Preview completed. Review the table list before resetting.",
      "success"
    );
  }

  async function loadPreview() {
    const button =
      document.querySelector(
        "#factory-preview-button"
      );

    if (button) {
      button.disabled = true;
      button.textContent =
        "Loading preview...";
    }

    setStatus(
      "Checking all MindPulse database tables...",
      "neutral"
    );

    try {
      const preview =
        await factoryRequest(
          "GET",
          previewEndpoint
        );

      renderPreview(preview);
    } catch (error) {
      setStatus(
        error.message,
        "danger"
      );
    } finally {
      if (button) {
        button.disabled = false;
        button.textContent =
          "Refresh preview";
      }
    }
  }

  function openDialog() {
    if (!currentPreview) {
      setStatus(
        "Generate the Factory Reset preview first.",
        "warning"
      );

      return;
    }

    const dialog =
      document.querySelector(
        "#factory-reset-dialog"
      );

    const requiredPhrase =
      document.querySelector(
        "#factory-required-phrase"
      );

    const password =
      document.querySelector(
        "#factory-admin-password"
      );

    const phrase =
      document.querySelector(
        "#factory-confirmation-phrase"
      );

    const output =
      document.querySelector(
        "#factory-dialog-output"
      );

    requiredPhrase.textContent =
      currentPreview.confirmationPhrase;

    password.value = "";
    phrase.value = "";

    output.hidden = true;
    output.textContent = "";

    dialog.showModal();
    password.focus();
  }

  async function submitReset(event) {
    event.preventDefault();

    const password =
      document.querySelector(
        "#factory-admin-password"
      )?.value || "";

    const confirmationPhrase =
      document.querySelector(
        "#factory-confirmation-phrase"
      )?.value.trim() || "";

    const required =
      currentPreview
        ?.confirmationPhrase || "";

    const submitButton =
      document.querySelector(
        "#factory-confirm-reset"
      );

    const output =
      document.querySelector(
        "#factory-dialog-output"
      );

    if (!password) {
      output.hidden = false;
      output.textContent =
        "Enter the Super Admin password.";

      return;
    }

    if (confirmationPhrase !== required) {
      output.hidden = false;
      output.textContent =
        "The confirmation phrase is incorrect.";

      return;
    }

    submitButton.disabled = true;
    submitButton.textContent =
      "Backing up and resetting...";

    output.hidden = false;
    output.textContent =
      "Creating the full SQL backup. Do not close this page.";

    try {
      const result =
        await factoryRequest(
          "POST",
          resetEndpoint,
          {
            password,
            confirmationPhrase
          }
        );

      output.textContent =
        [
          "FACTORY RESET COMPLETED",
          "",
          `Deleted rows: ${number(result.deletedRows)}`,
          `SQL backup: ${result.backupFile}`,
          `Reset receipt: ${result.receiptFile || "Not created"}`,
          "",
          "Super Admin account and information were preserved.",
          "All user sessions were revoked."
        ].join("\n");

      setStatus(
        "Factory Reset completed. All resettable data is now zero.",
        "success"
      );

      window.setTimeout(
        () => {
          document
            .querySelector("#logout-button")
            ?.click();
        },
        5000
      );
    } catch (error) {
      output.textContent =
        error.message;

      submitButton.disabled = false;
      submitButton.textContent =
        "Run Factory Reset";
    }
  }

  function renderFactoryResetPage() {
    document
      .querySelectorAll(".nav-item")
      .forEach((item) => {
        item.classList.remove("is-active");
      });

    document
      .querySelector(
        '[data-view="factory-reset"]'
      )
      ?.classList.add("is-active");

    const title =
      document.querySelector(
        "#page-title"
      );

    const subtitle =
      document.querySelector(
        ".page-subtitle"
      );

    const actions =
      document.querySelector(
        "#page-actions"
      );

    const content =
      document.querySelector(
        "#content"
      );

    if (title) {
      title.textContent =
        "Factory Reset";
    }

    if (subtitle) {
      subtitle.textContent =
        "Reset all MindPulse data except protected Admin information";
    }

    actions?.replaceChildren();

    if (!content) {
      return;
    }

    content.innerHTML = `
      <section class="factory-reset-hero">
        <div>
          <span class="factory-kicker">
            Super Admin only
          </span>

          <h2>Reset everything to zero</h2>

          <p>
            All users, wellness activity, reports, AI data,
            journals, habits, notifications, logs and sessions
            will be cleared. Super Admin information and required
            application reference data will remain.
          </p>
        </div>

        <div class="factory-protection">
          SQL backup required
        </div>
      </section>

      <div
        id="factory-reset-status"
        class="factory-reset-status factory-reset-status-neutral"
      >
        Generate a preview before running Factory Reset.
      </div>

      <section class="factory-summary-grid">
        <article class="factory-summary-card">
          <span>Rows that will become zero</span>

          <strong id="factory-total-rows">
            —
          </strong>

          <button
            id="factory-preview-button"
            type="button"
          >
            Generate Factory Reset preview
          </button>
        </article>

        <article class="factory-summary-card factory-safe-card">
          <span>Super Admin information</span>

          <strong>Protected</strong>

          <p>
            Admin account, email, password and role
            cannot be removed by Factory Reset.
          </p>
        </article>
      </section>

      <section class="factory-columns">
        <article class="panel">
          <div class="panel-header">
            <h2>Tables that will become zero</h2>
          </div>

          <div
            id="factory-reset-tables"
            class="factory-table-list"
          >
            <p class="factory-empty">
              Preview has not been generated.
            </p>
          </div>
        </article>

        <article class="panel">
          <div class="panel-header">
            <h2>Protected tables</h2>
          </div>

          <div
            id="factory-protected-tables"
            class="factory-table-list"
          >
            <p class="factory-empty">
              Preview has not been generated.
            </p>
          </div>
        </article>
      </section>

      <section class="factory-danger-zone">
        <div>
          <span class="factory-kicker">
            Danger zone
          </span>

          <h2>Factory Reset MindPulse</h2>

          <p>
            A complete SQL backup must succeed before any data
            is removed. Super Admin password and exact typed
            confirmation are required.
          </p>
        </div>

        <button
          id="factory-open-dialog"
          type="button"
          class="factory-danger-button"
          disabled
        >
          Factory Reset
        </button>
      </section>

      <dialog
        id="factory-reset-dialog"
        class="action-dialog"
      >
        <form id="factory-reset-form">
          <div class="dialog-header">
            <div>
              <span class="factory-kicker">
                Final confirmation
              </span>

              <h2>Reset all MindPulse data?</h2>
            </div>

            <button
              id="factory-close-dialog"
              type="button"
              class="icon-button"
              aria-label="Close"
            >
              ×
            </button>
          </div>

          <p class="dialog-description">
            All resettable database tables will become zero.
            Your Super Admin information will remain unchanged.
          </p>

          <label>
            Super Admin password

            <input
              id="factory-admin-password"
              type="password"
              autocomplete="current-password"
              required
            />
          </label>

          <label>
            Type this phrase exactly

            <code id="factory-required-phrase"></code>

            <input
              id="factory-confirmation-phrase"
              type="text"
              autocomplete="off"
              spellcheck="false"
              required
            />
          </label>

          <pre
            id="factory-dialog-output"
            class="dialog-output"
            hidden
          ></pre>

          <div class="dialog-footer">
            <button
              id="factory-cancel-reset"
              type="button"
              class="button-secondary"
            >
              Cancel
            </button>

            <button
              id="factory-confirm-reset"
              type="submit"
              class="factory-danger-button"
            >
              Run Factory Reset
            </button>
          </div>
        </form>
      </dialog>
    `;

    document
      .querySelector(
        "#factory-preview-button"
      )
      ?.addEventListener(
        "click",
        loadPreview
      );

    document
      .querySelector(
        "#factory-open-dialog"
      )
      ?.addEventListener(
        "click",
        openDialog
      );

    document
      .querySelector(
        "#factory-reset-form"
      )
      ?.addEventListener(
        "submit",
        submitReset
      );

    const closeDialog = () => {
      document
        .querySelector(
          "#factory-reset-dialog"
        )
        ?.close();
    };

    document
      .querySelector(
        "#factory-close-dialog"
      )
      ?.addEventListener(
        "click",
        closeDialog
      );

    document
      .querySelector(
        "#factory-cancel-reset"
      )
      ?.addEventListener(
        "click",
        closeDialog
      );

    loadPreview();
  }

  function injectNavigation() {
    if (
      document.querySelector(
        '[data-view="factory-reset"]'
      )
    ) {
      return;
    }

    const navigation =
      document.querySelector(
        ".navigation"
      );

    if (!navigation) {
      return;
    }

    const button =
      document.createElement("button");

    button.type = "button";
    button.className = "nav-item";
    button.dataset.view = "factory-reset";
    button.textContent = "Factory Reset";

    button.addEventListener(
      "click",
      (event) => {
        event.preventDefault();
        event.stopPropagation();

        renderFactoryResetPage();
      }
    );

    const auditButton =
      navigation.querySelector(
        '[data-view="audit"]'
      );

    if (auditButton) {
      navigation.insertBefore(
        button,
        auditButton
      );
    } else {
      navigation.append(button);
    }
  }

  function initializeFactoryReset() {
    injectNavigation();

    const observer =
      new MutationObserver(() => {
        injectNavigation();
      });

    observer.observe(
      document.body,
      {
        childList: true,
        subtree: true
      }
    );
  }

  if (
    document.readyState ===
    "loading"
  ) {
    document.addEventListener(
      "DOMContentLoaded",
      initializeFactoryReset,
      {
        once: true
      }
    );
  } else {
    initializeFactoryReset();
  }
})();
// END MINDPULSE FACTORY RESET UI