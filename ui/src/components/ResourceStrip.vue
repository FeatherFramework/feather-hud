<script setup>
import { computed } from 'vue';
import { useResourceStripStore } from '@/store/resourceStrip';
import moneyIcon from '@/assets/icons/money.png';
import goldIcon from '@/assets/icons/gold.png';
import tokenIcon from '@/assets/icons/token.png';
import shieldIcon from '@/assets/icons/shield.png';
import { splitCurrency } from '@/store/currency';

const store = useResourceStripStore();

// Ported from the design handoff's Resource Strip.dc.html renderVals() --
// same anchor -> layout derivation, just as Vue computeds instead of a
// one-shot prop function.
const anchorParts = computed(() => {
  const [v, h] = (store.anchor || 'bottom-right').split('-');
  return { v, h };
});

const side = computed(() => {
  const { h } = anchorParts.value;
  return h === 'left' ? 'left' : h === 'center' ? 'center' : 'right';
});

const alignItems = computed(() => {
  const { v } = anchorParts.value;
  return v === 'top' ? 'flex-start' : v === 'middle' ? 'center' : 'flex-end';
});

const justifyContent = computed(() => {
  return side.value === 'left' ? 'flex-start' : side.value === 'center' ? 'center' : 'flex-end';
});

// Same left/center/right -> flex-start/center/flex-end mapping as
// justifyContent, kept as its own computed since it drives a different
// property (column cross-axis alignment, not the outer overlay).
const crossAlign = computed(() => justifyContent.value);

const rowDir = computed(() => (side.value === 'left' ? 'row-reverse' : 'row'));
const scrimX = computed(() => (side.value === 'left' ? '0%' : side.value === 'center' ? '50%' : '100%'));

const ruleGradient = computed(() => {
  if (side.value === 'left') {
    return 'linear-gradient(270deg, rgba(177,147,40,0) 0%, rgba(177,147,40,0.55) 22%, rgba(214,192,152,0.7) 100%)';
  }
  if (side.value === 'center') {
    return 'linear-gradient(90deg, rgba(177,147,40,0) 0%, rgba(214,192,152,0.7) 50%, rgba(177,147,40,0) 100%)';
  }
  return 'linear-gradient(90deg, rgba(177,147,40,0) 0%, rgba(177,147,40,0.55) 22%, rgba(214,192,152,0.7) 100%)';
});

const scrimGradient = computed(() => {
  return `radial-gradient(70% 120% at ${scrimX.value} 50%, rgba(12,9,6,0.60) 0%, rgba(12,9,6,0.30) 48%, rgba(12,9,6,0.00) 78%)`;
});

const rootStyle = computed(() => ({
  alignItems: alignItems.value,
  justifyContent: justifyContent.value,
  // RedM draws its own connection/server-tag text in the top-right corner
  // that padding alone (26px by default) doesn't clear -- top-anchored
  // positions get their own, taller clearance (topPadding) instead of
  // reusing the regular edge padding.
  paddingTop: `${anchorParts.value.v === 'top' ? store.topPadding : store.padding}px`,
  paddingBottom: `${store.padding}px`,
  paddingLeft: `${store.padding}px`,
  paddingRight: `${store.padding}px`
}));

const columnStyle = computed(() => {
  const vSide = anchorParts.value.v === 'top' ? 'top' : anchorParts.value.v === 'middle' ? 'center' : 'bottom';
  const hSide = side.value === 'left' ? 'left' : side.value === 'center' ? 'center' : 'right';
  return {
    alignItems: crossAlign.value,
    textAlign: side.value,
    transform: `scale(${store.scale})`,
    transformOrigin: `${hSide} ${vSide}`
  };
});

// RANK IX-style roman numerals -- pure display formatting of the level
// integer hud.lua already computed, not data it needs to know about.
const ROMAN_NUMERALS = [
  [1000, 'M'], [900, 'CM'], [500, 'D'], [400, 'CD'],
  [100, 'C'], [90, 'XC'], [50, 'L'], [40, 'XL'],
  [10, 'X'], [9, 'IX'], [5, 'V'], [4, 'IV'], [1, 'I']
];
function toRoman(num) {
  let remaining = Math.max(1, Math.floor(num));
  let result = '';
  for (const [value, symbol] of ROMAN_NUMERALS) {
    while (remaining >= value) {
      result += symbol;
      remaining -= value;
    }
  }
  return result;
}
const rankLabel = computed(() => `RANK ${toRoman(store.level)}`);
const xpDisplay = computed(() => Math.floor(store.xp).toLocaleString('en-US'));

const cashParts = computed(() => splitCurrency(store.cashMinor, store.cashPrecision));
const goldParts = computed(() => splitCurrency(store.goldMinor, store.goldPrecision));
const tokensDisplay = computed(() => Math.floor(store.tokens ?? 0));
</script>

<template>
  <div v-if="store.visible" class="rs-root" :style="rootStyle">
    <div class="rs-column" :style="columnStyle">
      <div v-if="store.scrim" class="rs-scrim" :style="{ background: scrimGradient }"></div>

      <div class="rs-xp-row" :style="{ flexDirection: rowDir }">
        <span class="rs-rank-label">{{ rankLabel }}</span>
        <div class="rs-xp-track">
          <div class="rs-xp-fill" :style="{ width: store.xpPercent + '%' }"></div>
        </div>
        <span class="rs-xp-value">{{ xpDisplay }}</span>
        <div class="rs-shield">
          <img :src="shieldIcon" alt="" class="rs-shield-img" />
          <span class="rs-shield-level">{{ store.level }}</span>
        </div>
      </div>

      <div class="rs-rule" :style="{ background: ruleGradient }"></div>

      <div class="rs-currency-row">
        <div class="rs-currency-group">
          <img :src="moneyIcon" alt="cash" class="rs-icon" />
          <span class="rs-numeral rs-cash">{{ cashParts.whole }}<span v-if="cashParts.frac" class="rs-numeral-frac rs-cash-frac">.{{ cashParts.frac }}</span></span>
        </div>
        <div class="rs-tick"></div>
        <div class="rs-currency-group">
          <img :src="goldIcon" alt="gold" class="rs-icon" />
          <span class="rs-numeral rs-gold">{{ goldParts.whole }}<span v-if="goldParts.frac" class="rs-numeral-frac rs-gold-frac">.{{ goldParts.frac }}</span></span>
        </div>
        <div class="rs-tick"></div>
        <div class="rs-currency-group">
          <img :src="tokenIcon" alt="tokens" class="rs-icon" />
          <span class="rs-numeral rs-token">{{ tokensDisplay }}</span>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.rs-root {
  position: fixed;
  inset: 0;
  pointer-events: none;
  display: flex;
}

.rs-column {
  position: relative;
  display: flex;
  flex-direction: column;
  gap: 7px;
}

.rs-scrim {
  position: absolute;
  left: -34px;
  right: -34px;
  top: -26px;
  bottom: -26px;
  pointer-events: none;
}

.rs-xp-row {
  position: relative;
  display: flex;
  align-items: center;
  gap: 9px;
  text-shadow: 0 1px 3px rgba(0, 0, 0, 0.95), 0 0 12px rgba(0, 0, 0, 0.6);
}

.rs-rank-label {
  font-family: rdrlino, Georgia, serif;
  font-size: 11px;
  letter-spacing: 0.22em;
  text-transform: uppercase;
  color: rgba(214, 192, 152, 0.88);
  /* Small text at low opacity washes out over bright backgrounds (sky,
     snow) even with the row's shared shadow -- a tighter, darker shadow
     of its own gives it a crisp edge instead of relying on that soft
     12px blur alone. */
  text-shadow: 0 1px 2px rgba(0, 0, 0, 1), 0 0 3px rgba(0, 0, 0, 0.95);
}

.rs-xp-track {
  position: relative;
  width: 132px;
  height: 5px;
  background: rgba(0, 0, 0, 0.5);
  box-shadow: inset 0 1px 2px rgba(0, 0, 0, 0.8), 0 0 0 1px rgba(177, 147, 40, 0.28);
}

.rs-xp-fill {
  position: absolute;
  top: 0;
  left: 0;
  bottom: 0;
  background: linear-gradient(180deg, #c96a5a, #8d3b2e);
  transition: width 400ms ease-out;
}

.rs-xp-value {
  font-family: chinarocks, sans-serif;
  font-size: 15px;
  letter-spacing: 0.04em;
  color: rgba(240, 229, 207, 0.82);
}

.rs-shield {
  position: relative;
  width: 30px;
  height: 30px;
  display: flex;
  align-items: center;
  justify-content: center;
}

.rs-shield-img {
  width: 30px;
  height: 30px;
  opacity: 0.9;
  filter: drop-shadow(0 1px 2px rgba(0, 0, 0, 0.9));
}

.rs-shield-level {
  position: absolute;
  font-family: chinarocks, sans-serif;
  font-size: 13px;
  color: #1b1208;
  text-shadow: none;
}

.rs-rule {
  position: relative;
  width: 100%;
  height: 1px;
}

.rs-currency-row {
  position: relative;
  display: flex;
  align-items: center;
  gap: 14px;
  text-shadow: 0 1px 3px rgba(0, 0, 0, 0.95), 0 0 12px rgba(0, 0, 0, 0.6);
}

.rs-currency-group {
  display: flex;
  align-items: center;
  gap: 6px;
}

.rs-icon {
  width: 26px;
  height: 26px;
  opacity: 0.92;
  filter: drop-shadow(0 1px 2px rgba(0, 0, 0, 0.9));
}

.rs-tick {
  width: 1px;
  height: 18px;
  background: rgba(214, 192, 152, 0.3);
}

.rs-numeral {
  font-family: chinarocks, sans-serif;
  font-size: 27px;
  line-height: 1;
}

.rs-numeral-frac {
  font-size: 17px;
}

.rs-cash {
  color: #efe6d2;
}

.rs-cash-frac {
  color: rgba(239, 230, 210, 0.7);
}

.rs-gold {
  color: #b19328;
}

.rs-gold-frac {
  color: rgba(177, 147, 40, 0.75);
}

.rs-token {
  color: #0195cc;
}
</style>
