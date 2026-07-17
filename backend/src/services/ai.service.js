class AiServiceError extends Error {
    constructor(
        message,
        {
            code = "AI_SERVICE_ERROR",
            statusCode = 502,
            upstreamStatus = null,
            details = null,
        } = {}
    ) {
        super(message);

        this.name = "AiServiceError";
        this.code = code;
        this.statusCode = statusCode;
        this.upstreamStatus = upstreamStatus;
        this.details = details;
    }
}


function getConfiguration({
    requireApiKey = true,
} = {}) {
    const baseUrl = (
        process.env.AI_SERVICE_URL || ""
    )
        .trim()
        .replace(/\/+$/, "");

    const apiKey = (
        process.env.AI_SERVICE_API_KEY || ""
    ).trim();

    const parsedTimeout = Number.parseInt(
        process.env.AI_SERVICE_TIMEOUT_MS ||
            "10000",
        10
    );

    const timeoutMs =
        Number.isFinite(parsedTimeout) &&
        parsedTimeout > 0
            ? parsedTimeout
            : 10000;

    if (!baseUrl) {
        throw new AiServiceError(
            "AI_SERVICE_URL is not configured.",
            {
                code:
                    "AI_SERVICE_CONFIGURATION_ERROR",
                statusCode: 500,
            }
        );
    }

    if (requireApiKey && !apiKey) {
        throw new AiServiceError(
            "AI_SERVICE_API_KEY is not configured.",
            {
                code:
                    "AI_SERVICE_CONFIGURATION_ERROR",
                statusCode: 500,
            }
        );
    }

    return {
        baseUrl,
        apiKey,
        timeoutMs,
    };
}


async function parseResponse(response) {
    const responseText =
        await response.text();

    if (!responseText) {
        return null;
    }

    try {
        return JSON.parse(responseText);
    } catch {
        return {
            raw_response: responseText,
        };
    }
}


async function request(
    endpoint,
    {
        method = "GET",
        body = null,
        authenticated = true,
    } = {}
) {
    const {
        baseUrl,
        apiKey,
        timeoutMs,
    } = getConfiguration({
        requireApiKey: authenticated,
    });

    const controller =
        new AbortController();

    const timeout = setTimeout(
        () => controller.abort(),
        timeoutMs
    );

    const headers = {
        Accept: "application/json",
    };

    if (authenticated) {
        headers["X-Internal-API-Key"] =
            apiKey;
    }

    if (body !== null) {
        headers["Content-Type"] =
            "application/json";
    }

    let response;

    try {
        response = await fetch(
            `${baseUrl}${endpoint}`,
            {
                method,
                headers,
                body:
                    body === null
                        ? undefined
                        : JSON.stringify(body),
                signal: controller.signal,
            }
        );
    } catch (error) {
        if (error.name === "AbortError") {
            throw new AiServiceError(
                "AI service request timed out.",
                {
                    code:
                        "AI_SERVICE_TIMEOUT",
                    statusCode: 504,
                }
            );
        }

        throw new AiServiceError(
            "AI service is currently unavailable.",
            {
                code:
                    "AI_SERVICE_UNAVAILABLE",
                statusCode: 503,
                details: {
                    reason: error.message,
                },
            }
        );
    } finally {
        clearTimeout(timeout);
    }

    const data =
        await parseResponse(response);

    if (!response.ok) {
        throw new AiServiceError(
            "AI service rejected the request.",
            {
                code:
                    "AI_SERVICE_UPSTREAM_ERROR",
                statusCode: 502,
                upstreamStatus:
                    response.status,
                details: data,
            }
        );
    }

    return data;
}


async function health() {
    return request(
        "/health",
        {
            authenticated: false,
        }
    );
}


async function analyzeJournal(payload) {
    return request(
        "/api/v1/analyze/journal",
        {
            method: "POST",
            body: payload,
        }
    );
}


async function checkSafety(payload) {
    return request(
        "/api/v1/safety/check",
        {
            method: "POST",
            body: payload,
        }
    );
}


async function getWellnessRecommendations(
    payload
) {
    return request(
        "/api/v1/recommendations/wellness",
        {
            method: "POST",
            body: payload,
        }
    );
}


async function predictWellness(
    payload
) {
    return request(
        "/api/v1/predictions/wellness",
        {
            method: "POST",
            body: payload,
        }
    );
}


module.exports = {
    AiServiceError,
    health,
    analyzeJournal,
    checkSafety,
    getWellnessRecommendations,
    predictWellness,
};
