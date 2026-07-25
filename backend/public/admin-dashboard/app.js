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