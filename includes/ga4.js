// Pull one key out of the GA4 event_params array as a column.
// GA4 stores each value in a typed slot, so the caller picks the slot.
function eventParam(key, type = "string") {
  const slot = { string: "string_value", int: "int_value" }[type];
  return `(SELECT value.${slot} FROM UNNEST(event_params) WHERE key = '${key}')`;
}

// The store's own domains. Sessions "referred" by them broke at a subdomain hop
// (see docs/exploration.md section 4); in GA4 these would be unwanted referrals.
const SELF_REFERRAL_DOMAINS = ["shop.googlemerchandisestore.com", "googlemerchandisestore.com"];

// Channel rules from docs/exploration.md section 4. CASE takes the first match, so order matters:
// medium before source (keeps '<Other> / organic' in Organic Search), self-referral before referral.
function channelGroup(source, medium) {
  const domains = SELF_REFERRAL_DOMAINS.map((d) => `'${d}'`).join(", ");
  return `CASE
      WHEN ${medium} = 'organic' THEN 'Organic Search'
      WHEN ${medium} = 'cpc' THEN 'Paid Search'
      WHEN ${medium} = 'referral' AND ${source} IN (${domains}) THEN 'Self-referral'
      WHEN ${medium} = 'referral' THEN 'Referral'
      WHEN ${source} = '(direct)' AND ${medium} = '(none)' THEN 'Direct'
      WHEN ${medium} = 'email' THEN 'Email'
      WHEN ${medium} = 'affiliate' THEN 'Affiliates'
      ELSE 'Unassigned'
    END`;
}

module.exports = { eventParam, channelGroup };
