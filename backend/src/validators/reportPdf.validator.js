function validatePositiveId(value, label) {
    const id = Number(value);

    if (!Number.isSafeInteger(id) || id <= 0) {
        return {
            errors: [
                `${label} must be a positive integer.`
            ],
            id: null
        };
    }

    return {
        errors: [],
        id
    };
}

module.exports = {
    validatePositiveId
};
