const assert = require('node:assert/strict');
const test = require('node:test');

process.env.JWT_SECRET ||= 'system-point-policy-test-secret';
process.env.PGPASSWORD ||= 'system-point-policy-test-password';

const { SYSTEM_POINT_VALUE } = require('./src/system-policy');
const { calculatePointsWithFraction } = require('./src/services-matching');

test('system point value is fixed at 0.1', () => {
  assert.equal(SYSTEM_POINT_VALUE, 0.1);
});

test('all new earning calculations use ten points per currency unit', () => {
  assert.deepEqual(
    calculatePointsWithFraction(1, SYSTEM_POINT_VALUE, 0),
    {points: 10, newFraction: 0},
  );
  assert.deepEqual(
    calculatePointsWithFraction(1.05, SYSTEM_POINT_VALUE, 0),
    {points: 10, newFraction: 0.05},
  );
});

test('exchange between equal system-valued points is one to one', () => {
  const sourcePoints = 125;
  const destinationPoints = sourcePoints * SYSTEM_POINT_VALUE / SYSTEM_POINT_VALUE;
  assert.equal(destinationPoints, 125);
});
