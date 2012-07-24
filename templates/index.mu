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

  function syncInputs(anchor) {
    if (anchor !== 'l') {
      $('#left input.currency').val(left_currency);
      $('#left select.currency option[value="' + left_currency + '"]').prop('selected', true);
      $('#left input.units').val(fromUSD(USD, left_currency));
    }
    if (anchor !== 'r') {
      $('#right input.currency').val(right_currency);
      $('#right select.currency option[value="' + right_currency + '"]').prop('selected', true);
      $('#right input.units').val(fromUSD(USD, right_currency));
    }
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
    var left_units = $(this).find('input.units').val();
    USD = toUSD(left_units, left_currency);
    syncInputs('l');
    syncPlatform();
  });
  $('#right').on('change', function(event, currency) {
    if (currency && right_currency !== currency) {
      right_currency = currency;
      $(this).find('option[value="' + right_currency + '"]').prop('selected', true);
      $(this).find('input.currency').val(right_currency);
    }
    var right_units = $(this).find('input.units').val();
    USD = toUSD(right_units, right_currency);
    syncInputs('r');
    syncPlatform();
  });


  function separateThousands(x, separator) {
    return x.toString().replace(/\B(?=(\d{3})+(?!\d))/g, separator);
  }
  function parseMoney(str) {
    if (str.match(/,.*\./)) {
      // commas then dot (american):
      return parseFloat(str.replace(/,/g, ''));
    }
    else if (str.match(/\..*,/)) {
      // dot then comma (euro)
      return parseFloat(str.replace(/\./g, '').replace(/,/g, '.'));
    }
    else {
      // only one type: ambiguous
      return parseFloat(str.replace(/[.,]/g, ''));
    }
  }
  function toUSD(units, currency) {
    return parseMoney(units) / rates[currency];
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
    cols = [{x: (left_x - 75), color: '#062109'}, {x: (right_x - 75), color: '#0a810d'}],
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
    real_y = y = constrain(usdScale(USD), 0, control_height);
    platform.attr("transform", "translate(0," + y + ")");
  }
  platform.selectAll('rect.slider').data(cols)
    .enter()
      .append("g")
        .attr("transform", function(d) { return "translate(" + d + ",0)"; })
        .append('rect')
          .attr('fill', function(d, i) { return  'slider slider' + (i + 1); })
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

  function Plot(lines) {
  }


  function Line(name) {
    this.pts = [];
  }
  Line.prototype.add = function(x, y) {
    this.pts.push({x: x, y: y});
  };
  Line.prototype.draw = function(xScale, yScale) {
    return d3.svg.line()
      .x(function(d, i) { return xScale(d.x); })
      .y(function(d, i) { return yScale(d.y); })
      (this.pts);
  }

  function drawBg() {
    var bg_svg = d3.select("#bg").append("svg")
      .attr("width", document.width)
      .attr("height", document.height);

    var y_min = 0.9,
      y_max = 1.2,
      names = Object.keys(currencies),
      lines = names.map(function(name) { return new Line(name); }),
      base_hist = historical_rates[t === 0 ? t : 0];
    console.log(lines);
    for (var t = 0, tlen = historical_rates.length; t < tlen; t++) {
      var hist = historical_rates[t];        
      hist.dt = new Date(hist.dt);
      names.forEach(function(name, i) {
        var y = hist.rates[name] / base_hist.rates[name];
        lines[i].add(hist.dt, y);
      });
    }

    var x_min = base_hist.dt,
      x_max = hist.dt,
      xScale = d3.scale.linear().domain([x_min, x_max]).range([0, document.width]),
      yScale = d3.scale.linear().domain([y_min, y_max]).range([0, document.height]),
      colorInterpolation = d3.interpolateHsl("#0f3a58", "#6f3a5f");

    bg_svg.selectAll('path')
      .data(lines)
    .enter().append('path')
      .attr('d', function(line) { return line.draw(xScale, yScale); })
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
    })
  }
  /*.on('click', function() {
    if (lastHighlight == -1) return;
    var url = "http://searchyc.com/" + articles[lastHighlight].name.toLowerCase().split(/[^a-z]+/i).join('+');
    window.location = url;
  });*/

});
</script>
