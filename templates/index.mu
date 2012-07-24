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
var historical_rates = {{{historical_rates | JSON.stringify}}},
  rates = {{{rates | JSON.stringify}}},
  currencies = {{{currencies | JSON.stringify}}},
  width = 0,
  height = 0,
  USD = localStorage.USD || 100,
  left_currency = localStorage.left_currency || 'USD',
  right_currency = localStorage.right_currency || 'ISK';

function constrain(num, min, max) {
  return Math.max(min, Math.min(max, num));
}

head.ready(function() {
  width = $("#chart").width();
  height = $("#chart").height();
  $('#input').width(width);
  var options = $.map(currencies, function(name, abbr) { return '<option value="' + abbr + '">' + name + '</option>'; }).join('');
  $('select.currency').append(options);

  $('#input input.currency').on('keyup', function() {
    var abbr = $(this).val().toUpperCase();
    if (currencies[abbr])
      $(this.parentNode.parentNode).trigger('change', abbr);
  });
  $('#input select.currency').on('change', function() {
    var abbr = $(this).children('option:selected').val();
    $(this.parentNode.parentNode).trigger('change', abbr);
  });
  $('#input input.units').on('keyup', function() {
    $(this.parentNode.parentNode).trigger('change');
  });

  function syncInputs() {
    $('#left input.currency').val(left_currency);
    $('#left select.currency option[value="' + left_currency + '"]').prop('selected', true);
    $('#left input.units').val(fromUSD(USD, left_currency));
    $('#right input.currency').val(right_currency);
    $('#right select.currency option[value="' + right_currency + '"]').prop('selected', true);
    $('#right input.units').val(fromUSD(USD, right_currency));
  }

  $(window).on('beforeunload', function() {
    localStorage.USD = USD;
    localStorage.left_currency = left_currency;
    localStorage.right_currency = right_currency;
  });
  $(function() {
    drawBg();
    syncInputs();
  });

  $('#left').on('change', function(event, currency) {
    if (currency && left_currency !== currency) {
      left_currency = currency;
      $(this).find('option[value="' + left_currency + '"]').prop('selected', true);
      $(this).find('input.currency').val(left_currency);
    }
    syncInputs();
  });
  $('#right').on('change', function(event, currency) {
    if (currency && right_currency !== currency) {
      right_currency = currency;
      $(this).find('option[value="' + right_currency + '"]').prop('selected', true);
      $(this).find('input.currency').val(right_currency);
    }
    syncInputs();
    // recalculate($('#right'), $('#left'));
  });


  function separateThousands(x, separator) {
    return x.toString().replace(/\B(?=(\d{3})+(?!\d))/g, separator);
  }
  function toUSD(units, currency) {
    return parseFloat(units) / rates[currency];
  }
  function fromUSD(units, currency) {
    var thousands = '.', decimal = ',';
    if (currency === 'USD') {
      thousands = ',';
      decimal = '.';
    }
    var parts = (units * rates[currency]).toFixed(2).split('.');
    if (units < 100) {
      return separateThousands(parts[0], thousands) + decimal + parts[1];
    }
    return separateThousands(parts[0], thousands) + decimal + '00';
  }

  // var margin = {top: 10, right: 10, bottom: 40, left: 10},
      // inner_width = width - margin.left - margin.right,
      // inner_height = height - margin.top - margin.bottom;

  // var formatNumber = d3.format(",.0f"),
      // format = function(d) { return formatNumber(d) + " TWh"; },
      // color = d3.scale.category20();

  var svg = d3.
    select("#chart")
      .attr("width", width)
      .attr("height", height)
      .append("svg")
        .attr("width", width)
        .attr("height", height);
  var g = svg.append("g")
    .attr("transform", "translate(10,10)")

  // link.append("title")
      // .text(function(d) { return d.source.name + " → " + d.target.name + "\n" + format(d.value); });
  var y = 0,
    real_y = 0,
    left_x = 100,
    right_x = width - 100,
    cols = [(left_x - 75), (right_x - 75)],
    control_height = height - 70,
    usdScale = d3.scale.log().domain([220000, 0.22]).range([0, control_height]);

  // y = 0 is $220000 USD
  // y = height - 50 is $.22 USD
  g.selectAll('rect.track').data(cols)
    .enter()
      .append('rect')
        .attr('x', function(d) { return d + 70; })
        .attr('y', 25)
        .attr('rx', 5)
        .attr('class', 'track')
        .attr('width', 10)
        .attr('height', control_height);

  var platform = g.append("g")//.selectAll(".node")
    .attr('class', 'platform')
    .attr("transform", "translate(0," + y + ")")
    .call(d3.behavior.drag().on("drag", drag).on("dragend", dragend))

  platform
    .append('rect')
      .attr('x', left_x)
      .attr('y', 25)
      .attr('class', 'track')
      .attr('width', width - 200)
      .attr('height', 1.5);

  function drag() {
    real_y += d3.event.dy;
    y = constrain(real_y, 0, control_height);
    platform.attr("transform", "translate(0," + y + ")");
    USD = usdScale.invert(y);
    syncInputs();
  }
  function dragend() {
    real_y = y;
  }
  function syncPlatform() {
    y = constrain(usdScale(USD), 0, control_height);
    platform.attr("transform", "translate(0," + y + ")");
  }
  platform.selectAll('rect.slider').data(cols)
    .enter()
      .append("g")
        .attr("transform", function(d) { return "translate(" + d + ",0)"; })
        .append('rect')
          .attr('class', function(d, i) { return 'slider slider' + (i + 1); })
          .attr('width', 150)
          .attr('height', 50);
        // .append('title')
        // .text(function(d) { return d.name + "\n" + format(d.value); });

  // node.append("text")
  //     .attr("x", -6)
  //     .attr("y", function(d) { return d.dy / 2; })
  //     .attr("dy", ".35em")
  //     .attr("text-anchor", "end")
  //     .attr("transform", null)
  //     .text(function(d) { return d.name; })
  //   .filter(function(d) { return d.x < width / 2; })
  //     .attr("x", 6 + sankey.nodeWidth())
  //     .attr("text-anchor", "start");

  // $("#container").width(width).height(height);
  function drawBg() {
    var bg_svg = d3.select("#bg").append("svg")
      .attr("width", document.width)
      .attr("height", document.height);
    // console.log(bg_svg);

    var names = Object.keys(currencies), lines = names.map(function() { return []; });
    historical_rates.forEach(function(historical_rate) {
      historical_rate.dt = new Date(historical_rate.dt);
      historical_rate.extent = d3.extent(names, function(name) { return historical_rate.rates[name]; });
      names.forEach(function(name, i) {
        lines[i].push({x: historical_rate.dt, y: historical_rate.rates[name]});
      });
    });

    var x_domain = d3.extent(historical_rates, function(h) { return h.dt; }),
      y_min = d3.min(historical_rates, function(h) { return h.extent[0]; }),
      y_max = d3.min(historical_rates, function(h) { return h.extent[1]; }),
      xScale = d3.scale.linear().domain(x_domain).range([0, document.width]),
      yScale = d3.scale.log().domain([y_min, y_max]).range([20, document.height - 40]),
      colorInterpolation = d3.interpolateHsl("#880000", "#0000AA"),
      colorScale = d3.scale.category20();

    // window.lines = lines;
    // window.names = names;
    bg_svg.selectAll('path')
      .data(lines)
    .enter().append('path')
      .attr('d', d3.svg.line()
        .x(function(d, i) { return xScale(d.x); })
        .y(function(d, i) { return yScale(d.y); })
      )
      .attr('fill', 'none')
      .attr('stroke', function(d, i) { return colorInterpolation(Math.random()); });

    var highlighter = bg_svg.append('g');
    highlighter.append('svg:circle').attr('fill', 'black').attr('r', 2.5);
    highlighter.append('svg:text').attr('fill', 'black').attr('x', 5).attr('y', -4);

    d3.select('body').on('mousemove', function() {
      var m = d3.svg.mouse(bg_svg[0][0]);
      var xI = xScale.invert(m[0]);
      var yI = yScale.invert(m[1]);
      var h = 0;
      for (var i = 0, l = historical_rates.length - 1; i < l; i++) {
        if (historical_rates[i].dt < xI && xI < historical_rates[i+1].dt) {
          h = historical_rates[i];
          break;
        }
      }
      var y_min = 1000000000, closest_name = '';
      names.forEach(function(name, i) {
        var dist = Math.abs(yI - h.rates[name]);
        if (dist < y_min) {
          y_min = dist;
          closest_name = name;
        }
      });

      var date = h.dt.toISOString().split(/T/)[0];
      highlighter
        .attr("transform", "translate(" + xScale(h.dt) + "," + yScale(h.rates[closest_name]) + ")")
        .select('text')
          .text(currencies[closest_name] + ': ' + h.rates[closest_name].toFixed(2) + ' (' + date + ')');
      // console.log(closest_name + ' (' + currencies[closest_name] + ') ' + h.rates[closest_name]);
      // var i = posToI(m[0]-padding.left, m[1]-padding.top);
      // highlightAt(i);
    })
  }
  /*.on('click', function() {
    if (lastHighlight == -1) return;
    var url = "http://searchyc.com/" + articles[lastHighlight].name.toLowerCase().split(/[^a-z]+/i).join('+');
    window.location = url;
  });*/
  

  // var g = svg.append("g")
    // 

});
</script>
