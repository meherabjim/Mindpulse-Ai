'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');

const {
    validateProfilePatch
} = require('../src/validators/account.validator');

const {
    validateRegister
} = require('../src/validators/auth.validator');

test('registration accepts phone and date of birth', () => {
    const result = validateRegister({
        full_name: 'Test User',
        phone_number: '+8801712345678',
        date_of_birth: '2000-01-15',
        email: 'test@example.com',
        password: 'Password123'
    });

    assert.deepEqual(result.errors, []);
    assert.equal(result.data.phoneNumber, '+8801712345678');
    assert.equal(result.data.dateOfBirth, '2000-01-15');
});

test('profile accepts body and water measurements', () => {
    const result = validateProfilePatch({
        weight_kg: 70.5,
        height_cm: 175,
        usual_water_ml: 2000,
        water_glass_ml: 250
    });

    assert.deepEqual(result.errors, []);
    assert.equal(result.data.weight_kg, 70.5);
    assert.equal(result.data.height_cm, 175);
});
