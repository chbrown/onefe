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
var rates = {{{rates | JSON.stringify}}},
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
  height = document.height * 0.85;
  $("#chart").height(height);
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
    var current_domain = usdScale.domain(); // [max, min]
    if (USD < current_domain[1]) {
      current_domain[1] = USD;
      usdScale = usdScale.domain(current_domain);
    }
    else if (USD > current_domain[0]) {
      current_domain[0] = USD;
      usdScale = usdScale.domain(current_domain);
    }
    // console.log('syncInputs', anchor, USD);
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
    syncInputs();
    syncPlatform();
    $.getJSON('/history.json', function(data, textStatus, jqXHR) {
      drawBg(data);
    });
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
    var multiple = 1;
    if (str.match(/k/i)) {
      multiple = 1000;
      str = str.replace(/k/i, '');
    } else if (str.match(/mi?/i)) {
      multiple = 1000000;
      str =str.replace(/mi?/i, '');
    }
    else if (str.match(/bi?/i)) {
      multiple = 1000000000;
      str = str.replace(/bi?/i, '');
    }


    if (str.match(/,\d{3},/) || str.match(/,.*\./) || str.match(/,.*,/)) {
      // commas then dot (american):
      str = str.replace(/,/g, '')
    }
    else if (str.match(/\.\d{3}\./) || str.match(/\..*,/) || str.match(/\..*\./)) {
      // dot then comma (euro)
      str = str.replace(/\./g, '').replace(/,/g, '.');
    }
    else {
      // only one type: ambiguous
      str = str.split(/[.,]/g, 2)[0]
    }
    return parseFloat(str) * multiple;
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

  var control_height = height - 70,
    usdScale = d3.scale.log().domain([220000, 0.22]).range([0, control_height]),
    y = constrain(usdScale(USD), 0, control_height),
    real_y = isNaN(y) ? 0 : y,
    left_x = 100,
    right_x = width - 100,
    cols = [{x: (left_x - 75), color: '#ef9952'}, {x: (right_x - 75), color: '#0a810d'}];


  // y = 0 is $220000 USD
  // y = height - 50 is $.22 USD
  g.selectAll('rect.track').data(cols)
    .enter()
      .append('rect')
        .attr('x', function(d) { return d.x + 70; })
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
    real_y = isNaN(real_y) ? 0 : real_y + d3.event.dy;
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
        .attr("transform", function(d) { return "translate(" + d.x + ",0)"; })
        .append('rect')
          .attr('fill', function(d) { return d.color; })
          .attr('stroke', function(d) { return d3.hsl(d.color).darker(2); })
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

  function Plot(names) {
    this.lines = names.map(function(name) { return new Line(name); });
  }
  Plot.prototype.nearest = function(x, y) {
    var self = this,
      xs = this.lines[0].pts.map(function(pt) { return pt.x.getTime(); }),
      xI = Plot.between(x, xs),
      // xI is now set to the line.pts[<index>] of the closest x-point
      yPts = this.lines.map(function(line) { return line.pts[xI]; }).sort(function(a, b) { return a.y - b.y; }),
      ys = yPts.map(function(yPt) { return yPt.y; }),
      yI = Plot.between(y, ys);

    return yPts[yI];
  };
  Plot.prototype.extentY = function() {
    var min = 1000000000, max = -1000000000;
    this.lines.forEach(function(line) {
      line.pts.forEach(function(pt) {
        min = Math.min(min, pt.y);
        max = Math.max(max, pt.y);
      })
    });
    return [min, max];
  };
  Plot.prototype.extentX = function() {
    var line0_pts = this.lines[0].pts,
      min = line0_pts[0].x,
      max = line0_pts[line0_pts.length - 1].x;
    return [min, max];
  };
  Plot.between = function(needle, haystack) {
    // haystack should already be sorted
    for (var i = 0, len = haystack.length; i < len; i++) {
      var straw = haystack[i], next_straw = haystack[i + 1];
      if (needle < next_straw) {
        return (needle - straw > next_straw - needle) ? i + 1 : i; // next_straw : straw
      }
    }
    return len - 1;
  };

  function Line(text) {
    this.text = text;
    this.pts = [];
  }
  Line.prototype.add = function(x, y, text) {
    this.pts.push({x: x, y: y, text: text, line: this});
  };
  Line.prototype.draw = function(xScale, yScale) {
    var d3_line = d3.svg.line()
      .x(function(d, i) { return xScale(d.x); })
      .y(function(d, i) { return yScale(d.y); })
      (this.pts);
    return d3_line;
  };

  function drawBg(historical_rates) {
    var bg_svg = d3.select("#bg").append("svg")
      .attr("width", document.width)
      .attr("height", document.height - 10);

    var abbrs = Object.keys(currencies),
      names = abbrs.map(function(abbr) { return currencies[abbr]; }),
      plot = new Plot(names),
      base_hist = historical_rates[t === 0 ? t : 0],
      colorInterpolation = d3.interpolateHsl(cols[0].color, cols[1].color);

    for (var t = 0, tlen = historical_rates.length; t < tlen; t++) {
      var hist = historical_rates[t];
      hist.dt = new Date(hist.dt);
      abbrs.forEach(function(abbr, abbr_i) {
        var y = hist.rates[abbr] / base_hist.rates[abbr];
        plot.lines[abbr_i].add(hist.dt, y, hist.dt.toISOString().split(/:/).slice(0, 2).join(':').replace(/T/, ' '));
      });
    }

    var xScale = d3.scale.linear().domain(plot.extentX()).range([0, document.width]),
      yScale = d3.scale.linear().domain([0.952, 1.05]).range([0, document.height]);


    bg_svg.selectAll('path')
      .data(plot.lines)
    .enter().append('path')
      .attr('d', function(line) { return line.draw(xScale, yScale); })
      .attr('fill', 'none')
      .attr('stroke', function(d, i) { return colorInterpolation(Math.random()); });

    var highlighter = bg_svg.append('g');
    highlighter.append('svg:circle').attr('fill', 'black').attr('r', 2.5);
    highlighter.append('svg:text').attr('fill', 'black').attr('x', 5).attr('y', -4);

    d3.select('body').on('mousemove', function() {
      var m = d3.svg.mouse(bg_svg[0][0]),
        pt = plot.nearest(xScale.invert(m[0]), yScale.invert(m[1]));

      highlighter
        .attr("transform", "translate(" + xScale(pt.x) + "," + yScale(pt.y) + ")")
        .select('text')
          .text(pt.line.text + ' (' + pt.text + ')');

      // closest_name] + ': ' + h.rates[closest_name].toFixed(2) + ' (' + date + ')'
      // console.log(closest_name + ' (' + currencies[closest_name] + ') ' + h.rates[closest_name]);
    })
  }

});
</script>
