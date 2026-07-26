'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');

const { validateRegister } = require('../src/validators/auth.validator');
const { validateProfilePatch } = require('../src/validators/account.validator');

test('Bangladesh local phone is normalized to E.164', () => {
    const result = validateRegister({
        full_name: 'Local Phone User',
        phone_number: '01712345678',
        date_of_birth: '2000-01-15',
        email: 'local-phone@example.com',
        password: 'Password123'
    });
    assert.deepEqual(result.errors, []);
    assert.equal(result.data.phoneNumber, '+8801712345678');
});

test('first login accepts sleep activity religion and permission choice', () => {
    const result = validateProfilePatch({
        typical_sleep_hours: 7.5,
        activity_pattern: 'moderately_active',
        religion: 'islam',
        prayer_alarm_enabled: false,
        permission_mode: 'choose'
    });
    assert.deepEqual(result.errors, []);
    assert.equal(result.data.typical_sleep_hours, 7.5);
    assert.equal(result.data.religion, 'islam');
    assert.equal(result.data.prayer_alarm_enabled, false);
});

test('unsupported religion and permission values are rejected', () => {
    const result = validateProfilePatch({
        religion: 'invented_value',
        permission_mode: 'everything_silently'
    });
    assert.equal(result.errors.length, 2);
});
