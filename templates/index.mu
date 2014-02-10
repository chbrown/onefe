<div id="bg"></div>
<div id="input">
  <div id="left">
    <div>
      <input type="text" class="units" placeholder="Amount" tabindex="1" />
      <input type="text" class="currency" placeholder="Abbr" tabindex="2" />
    </div>
    <div>
      <select type="text" class="currency"></select>
    </div>
  </div>
  <div id="right">
    <div>
      <input type="text" class="units" placeholder="Amount" tabindex="3" />
      <input type="text" class="currency" placeholder="Abbr" tabindex="4" />
    </div>
    <div>
      <select type="text" class="currency"></select>
    </div>
  </div>
</div>
<div id="chart"></div>

<script>
var current_rates = {{{JSON.stringify(current_rates)}}};
var currencies = {{{JSON.stringify(currencies)}}};
$(function() {
  load(current_rates, currencies);
});
</script>
