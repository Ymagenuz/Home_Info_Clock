const $ = (id) => document.getElementById(id);

    const el = {
      digitalTime: $("digitalTime"),
      dateLine: $("dateLine"),
      hourHand: $("hourHand"),
      minuteHand: $("minuteHand"),
      weatherLocation: $("weatherLocation"),
      weatherIcon: $("weatherIcon"),
      weatherText: $("weatherText"),
      temperature: $("temperature"),
      humidity: $("humidity"),
      windSpeed: $("windSpeed"),
      weatherNote: $("weatherNote"),
      forecastToday: $("forecastToday"),
      forecastTomorrow: $("forecastTomorrow"),
      clothingAdvice: $("clothingAdvice"),
      umbrellaAdvice: $("umbrellaAdvice"),
      outingAdvice: $("outingAdvice"),
      tomorrowRain: $("tomorrowRain"),
      tomorrowUv: $("tomorrowUv"),
      tomorrowWind: $("tomorrowWind"),
      tomorrowRange: $("tomorrowRange"),
      weeklyTrend: $("weeklyTrend"),
      weatherSlides: $("weatherSlides"),
      weatherTrack: $("weatherTrack"),
      weatherPager: $("weatherPager"),
      batteryLabel: $("batteryLabel"),
      batteryState: $("batteryState"),
      batteryFill: $("batteryFill"),
      slides: $("slides"),
      slideTrack: $("slideTrack"),
      pager: $("pager")
    };

    const weekdays = ["星期日", "星期一", "星期二", "星期三", "星期四", "星期五", "星期六"];
    const weatherCodeMap = {
      0: ["晴", "☀"],
      1: ["大致晴朗", "◐"],
      2: ["局部多云", "☁"],
      3: ["阴", "☁"],
      45: ["雾", "≋"],
      48: ["雾凇", "≋"],
      51: ["小毛毛雨", "☂"],
      53: ["毛毛雨", "☂"],
      55: ["大毛毛雨", "☂"],
      61: ["小雨", "☔"],
      63: ["中雨", "☔"],
      65: ["大雨", "☔"],
      80: ["阵雨", "☔"],
      81: ["阵雨", "☔"],
      82: ["强阵雨", "☔"],
      95: ["雷雨", "⚡"],
      96: ["雷雨冰雹", "⚡"],
      99: ["强雷雨冰雹", "⚡"]
    };

    let dimmed = false;
    let lastMinute = "";
    let weatherCurrentPage = 0;
    let weatherReturnTimer = null;
    let weatherRetryTimer = null;
    let currentPage = 0;
    const weatherPageCount = 3;
    const weatherReturnDelay = 30 * 1000;
    const pageCount = 3;

    function getConfiguredLocation() {
      const params = new URLSearchParams(location.search);
      if (!params.has("lat") || (!params.has("lon") && !params.has("lng"))) return null;

      const latitude = Number(params.get("lat"));
      const longitude = Number(params.get("lon") || params.get("lng"));

      if (Number.isFinite(latitude) && Number.isFinite(longitude)) {
        return {
          latitude,
          longitude,
          label: params.get("location") || "",
          source: "fixed"
        };
      }

      return null;
    }

    function normalizeLocation(raw, source) {
      if (!raw) return null;

      const latitude = Number(raw.latitude ?? raw.lat);
      const longitude = Number(raw.longitude ?? raw.lon ?? raw.lng);

      if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) return null;

      const label = raw.city || raw.locality || raw.town || raw.village || raw.region || "";
      return { latitude, longitude, label, source };
    }

    function getFullyKioskLocation() {
      try {
        if (!window.fully || typeof window.fully.getLocation !== "function") return null;

        const raw = JSON.parse(window.fully.getLocation());
        return normalizeLocation(raw, "fully");
      } catch (_) {
        return null;
      }
    }

    function getNativeAppLocation() {
      try {
        if (!window.HomePanelNative || typeof window.HomePanelNative.getLocation !== "function") {
          console.info("HomePanelNative.getLocation unavailable");
          return null;
        }

        const raw = JSON.parse(window.HomePanelNative.getLocation());
        console.info("HomePanelNative.getLocation", raw);
        if (!raw.ok) return null;
        return normalizeLocation(raw, "android");
      } catch (error) {
        console.error("HomePanelNative.getLocation failed", error && error.message ? error.message : error);
        return null;
      }
    }

    function getBrowserLocation() {
      return new Promise((resolve) => {
        if (!navigator.geolocation) {
          resolve(null);
          return;
        }

        navigator.geolocation.getCurrentPosition(
          ({ coords }) => resolve(normalizeLocation(coords, "browser")),
          () => resolve(null),
          { enableHighAccuracy: true, timeout: 9000, maximumAge: 30 * 60 * 1000 }
        );
      });
    }

    async function getLocationLabel(weatherLocation) {
      if (weatherLocation.label) return weatherLocation.label;

      try {
        const params = new URLSearchParams({
          latitude: weatherLocation.latitude.toFixed(6),
          longitude: weatherLocation.longitude.toFixed(6),
          localityLanguage: "zh"
        });
        const response = await fetch(`https://api.bigdatacloud.net/data/reverse-geocode-client?${params}`);
        if (!response.ok) throw new Error("reverse geocode failed");

        const data = await response.json();
        return data.city || data.locality || data.principalSubdivision || data.countryName || `位置 ${weatherLocation.latitude.toFixed(4)}, ${weatherLocation.longitude.toFixed(4)}`;
      } catch (_) {
        return `位置 ${weatherLocation.latitude.toFixed(4)}, ${weatherLocation.longitude.toFixed(4)}`;
      }
    }

    function pad(n) {
      return String(n).padStart(2, "0");
    }

    function updateClock() {
      const now = new Date();
      const hour = now.getHours();
      const minute = now.getMinutes();
      const minuteKey = `${hour}:${minute}`;
      const hourAngle = ((hour % 12) + minute / 60) * 30;
      const minuteAngle = minute * 6;

      el.hourHand.style.setProperty("--r", `${hourAngle}deg`);
      el.minuteHand.style.setProperty("--r", `${minuteAngle}deg`);
      el.digitalTime.textContent = `${pad(hour)}:${pad(minute)}`;

      if (minuteKey !== lastMinute) {
        lastMinute = minuteKey;
        el.dateLine.textContent = `${now.getFullYear()}年${now.getMonth() + 1}月${now.getDate()}日 ${weekdays[now.getDay()]}`;
        driftForBurnInProtection();
      }
    }

    function driftForBurnInProtection() {
      const x = Math.round((Math.random() - .5) * 10);
      const y = Math.round((Math.random() - .5) * 8);
      document.documentElement.style.setProperty("--drift-x", `${x}px`);
      document.documentElement.style.setProperty("--drift-y", `${y}px`);
    }

    function renderWeather(data, sourceLabel) {
      const current = data.current;
      const [condition, icon] = weatherCodeMap[current.weather_code] || ["未知天气", "·"];
      const time = new Date(current.time);

      el.weatherLocation.textContent = sourceLabel;
      el.weatherIcon.textContent = icon;
      el.weatherText.textContent = condition;
      el.temperature.textContent = `${Math.round(current.temperature_2m)}°`;
      el.humidity.textContent = `湿度 ${Math.round(current.relative_humidity_2m)}%`;
      el.windSpeed.textContent = `风 ${Math.round(current.wind_speed_10m)} km/h`;
      renderForecastCard(el.forecastToday, data.daily, 0, "今天");
      renderForecastCard(el.forecastTomorrow, data.daily, 1, "明天");
      renderTomorrowAdvice(data.daily);
      renderWeeklyTrend(data.daily);
      el.weatherNote.textContent = `更新 ${pad(time.getHours())}:${pad(time.getMinutes())} · 15分钟刷新`;
    }

    function renderForecastCard(card, daily, index, label) {
      if (!daily || !daily.time[index]) return;

      const code = daily.weather_code[index];
      const [condition, icon] = weatherCodeMap[code] || ["未知天气", "·"];
      const max = Math.round(daily.temperature_2m_max[index]);
      const min = Math.round(daily.temperature_2m_min[index]);
      const rain = daily.precipitation_probability_max ? daily.precipitation_probability_max[index] : null;

      card.querySelector(".forecast-icon").textContent = icon;
      card.querySelector(".forecast-day").textContent = label;
      card.querySelector(".forecast-condition").textContent = rain == null ? condition : `${condition} · 降水${rain}%`;
      card.querySelector(".forecast-temp").textContent = `${max}°/${min}°`;
    }

    function renderTomorrowAdvice(daily) {
      if (!daily || !daily.time[1]) return;

      const max = Math.round(daily.temperature_2m_max[1]);
      const min = Math.round(daily.temperature_2m_min[1]);
      const rain = daily.precipitation_probability_max ? daily.precipitation_probability_max[1] : 0;
      const wind = daily.wind_speed_10m_max ? Math.round(daily.wind_speed_10m_max[1]) : 0;
      const uv = daily.uv_index_max ? Math.round(daily.uv_index_max[1]) : 0;
      const range = max - min;

      el.tomorrowRain.textContent = `${rain}%`;
      el.tomorrowUv.textContent = uv >= 8 ? `${uv} 强` : uv >= 6 ? `${uv} 中高` : uv >= 3 ? `${uv} 中` : `${uv} 低`;
      el.tomorrowWind.textContent = wind ? `${wind} km/h` : "--";
      el.tomorrowRange.textContent = `${range}°`;

      let clothing = "短袖或轻薄透气衣物比较合适。";
      if (min <= 18) clothing = "早晚偏凉，建议加一件薄外套。";
      else if (max >= 32) clothing = "天气偏热，建议穿轻薄透气衣物。";
      else if (max <= 24) clothing = "温度舒适，可穿长袖或薄外套。";

      let umbrella = "降水概率不高，雨伞可按需携带。";
      if (rain >= 60) umbrella = "降水概率较高，建议带伞。";
      else if (rain >= 35) umbrella = "可能有雨，随身带一把折叠伞更稳。";

      const tips = [];
      if (uv >= 7) tips.push("紫外线较强，注意防晒");
      if (wind >= 30) tips.push("风力偏大，注意固定随身物品");
      if (max >= 32) tips.push("高温时段注意补水");
      if (tips.length === 0) tips.push("整体适合正常出行");

      el.clothingAdvice.textContent = clothing;
      el.umbrellaAdvice.textContent = umbrella;
      el.outingAdvice.textContent = tips.join("，") + "。";
    }

    function renderWeeklyTrend(daily) {
      if (!daily || !daily.time.length) return;

      const highs = daily.temperature_2m_max.map(Math.round);
      const lows = daily.temperature_2m_min.map(Math.round);
      const maxHigh = Math.max(...highs);
      const minLow = Math.min(...lows);
      el.weeklyTrend.innerHTML = "";

      daily.time.slice(0, 3).forEach((dateText, index) => {
        const date = new Date(`${dateText}T00:00:00`);
        const [condition, icon] = weatherCodeMap[daily.weather_code[index]] || ["未知", "·"];
        const high = highs[index];
        const low = lows[index];
        const rain = daily.precipitation_probability_max ? daily.precipitation_probability_max[index] : 0;
        const range = Math.max(1, maxHigh - minLow);
        const left = ((low - minLow) / range) * 100;
        const width = Math.max(14, ((high - low) / range) * 100);
        const row = document.createElement("div");

        row.className = "trend-row";
        row.innerHTML = `
          <span>${index === 0 ? "今天" : weekdays[date.getDay()].replace("星期", "周")}</span>
          <span>${icon}</span>
          <span class="trend-range">
            <span class="trend-low">${low}°</span>
            <span class="trend-track"><span class="trend-bar" style="--range-left:${left}%; --range-width:${width}%"></span></span>
            <span class="trend-high">${high}°</span>
          </span>
          <span class="trend-rain">💧 降水 ${rain}%</span>
        `;
        row.title = condition;
        el.weeklyTrend.appendChild(row);
      });
    }

    async function fetchWeather(latitude, longitude, sourceLabel) {
      const params = new URLSearchParams({
        latitude,
        longitude,
        current: "temperature_2m,relative_humidity_2m,weather_code,wind_speed_10m",
        daily: "weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max,wind_speed_10m_max,uv_index_max",
        forecast_days: "7",
        timezone: "auto"
      });
      const response = await fetch(`https://api.open-meteo.com/v1/forecast?${params}`);
      if (!response.ok) throw new Error("weather request failed");
      renderWeather(await response.json(), sourceLabel);
    }

    async function updateWeather() {
      const configuredLocation = getConfiguredLocation();
      const nativeLocation = configuredLocation ? null : getNativeAppLocation();
      const fullyLocation = configuredLocation || nativeLocation ? null : getFullyKioskLocation();
      const browserLocation = configuredLocation || nativeLocation || fullyLocation ? null : await getBrowserLocation();
      const weatherLocation = configuredLocation || nativeLocation || fullyLocation || browserLocation;
      console.info("updateWeather location", weatherLocation);

      if (!weatherLocation) {
        el.weatherLocation.textContent = "定位失败";
        el.weatherText.textContent = "未获取坐标";
        el.weatherNote.textContent = "正在等待定位，可在 URL 加 ?lat=纬度&lon=经度";
        scheduleWeatherRetry();
        return;
      }

      const locationLabel = await getLocationLabel(weatherLocation);

      fetchWeather(
        weatherLocation.latitude.toFixed(4),
        weatherLocation.longitude.toFixed(4),
        locationLabel
      ).catch(() => {
        el.weatherLocation.textContent = "天气暂不可用";
        el.weatherText.textContent = "网络或天气接口受限";
        el.weatherNote.textContent = "已获取位置，但天气请求失败";
        scheduleWeatherRetry();
      });
    }

    window.homePanelLocationUpdated = () => {
      updateWeather();
    };

    function scheduleWeatherRetry() {
      clearTimeout(weatherRetryTimer);
      weatherRetryTimer = setTimeout(updateWeather, 10 * 1000);
    }

    function renderWeatherPager() {
      el.weatherPager.innerHTML = "";
      for (let i = 0; i < weatherPageCount; i += 1) {
        const button = document.createElement("button");
        button.className = "page-dot";
        button.type = "button";
        button.setAttribute("aria-label", `切换到天气第 ${i + 1} 页`);
        button.setAttribute("aria-current", String(i === weatherCurrentPage));
        button.addEventListener("click", (event) => {
          event.stopPropagation();
          setWeatherPage(i);
          restartWeatherReturnTimer();
        });
        el.weatherPager.appendChild(button);
      }
    }

    function setWeatherPage(page) {
      weatherCurrentPage = (page + weatherPageCount) % weatherPageCount;
      el.weatherTrack.style.setProperty("--weather-page", weatherCurrentPage);
      [...el.weatherPager.children].forEach((dot, index) => {
        dot.setAttribute("aria-current", String(index === weatherCurrentPage));
      });
    }

    function restartWeatherReturnTimer() {
      clearTimeout(weatherReturnTimer);
      if (weatherCurrentPage === 0) return;

      weatherReturnTimer = setTimeout(() => {
        setWeatherPage(0);
      }, weatherReturnDelay);
    }

    function initWeatherSlider() {
      let startX = 0;
      let pointerDown = false;

      el.weatherSlides.addEventListener("pointerdown", (event) => {
        event.stopPropagation();
        pointerDown = true;
        startX = event.clientX;
        el.weatherSlides.setPointerCapture(event.pointerId);
      });

      el.weatherSlides.addEventListener("pointerup", (event) => {
        event.stopPropagation();
        if (!pointerDown) return;
        pointerDown = false;
        const delta = event.clientX - startX;
        if (Math.abs(delta) > 36) {
          setWeatherPage(weatherCurrentPage + (delta < 0 ? 1 : -1));
          restartWeatherReturnTimer();
        }
      });
    }

    function renderPager() {
      el.pager.innerHTML = "";
      for (let i = 0; i < pageCount; i += 1) {
        const button = document.createElement("button");
        button.className = "page-dot";
        button.type = "button";
        button.setAttribute("aria-label", `切换到第 ${i + 1} 页`);
        button.setAttribute("aria-current", String(i === currentPage));
        button.addEventListener("click", (event) => {
          event.stopPropagation();
          setPage(i);
        });
        el.pager.appendChild(button);
      }
    }

    function setPage(page) {
      currentPage = (page + pageCount) % pageCount;
      el.slideTrack.style.setProperty("--page", currentPage);
      [...el.pager.children].forEach((dot, index) => {
        dot.setAttribute("aria-current", String(index === currentPage));
      });
    }

    function initSlider() {
      let startX = 0;
      let pointerDown = false;

      el.slides.addEventListener("pointerdown", (event) => {
        pointerDown = true;
        startX = event.clientX;
        el.slides.setPointerCapture(event.pointerId);
      });

      el.slides.addEventListener("pointerup", (event) => {
        if (!pointerDown) return;
        pointerDown = false;
        const delta = event.clientX - startX;
        if (Math.abs(delta) > 42) {
          setPage(currentPage + (delta < 0 ? 1 : -1));
        }
      });
    }

    function toggleDim() {
      dimmed = !dimmed;
      document.documentElement.classList.toggle("dim", dimmed);
    }

    async function requestWakeLock() {
      try {
        if ("wakeLock" in navigator) {
          await navigator.wakeLock.request("screen");
        }
      } catch (_) {}
    }

    async function updateBattery() {
      try {
        if (window.HomePanelNative && typeof window.HomePanelNative.getBattery === "function") {
          const nativeBattery = JSON.parse(window.HomePanelNative.getBattery());
          if (nativeBattery.ok) {
            const pct = nativeBattery.level;
            el.batteryLabel.textContent = `电量 ${pct}%`;
            el.batteryState.textContent = nativeBattery.charging ? "充电中" : "使用电池";
            el.batteryFill.style.setProperty("--battery-level", `${pct}%`);
            el.batteryFill.closest(".battery-status").classList.toggle("is-charging", nativeBattery.charging);
            el.batteryFill.closest(".battery-status").classList.toggle("is-low", !nativeBattery.charging && pct <= 20);
            return;
          }
        }

        if (!navigator.getBattery) {
          el.batteryLabel.textContent = "电量不可用";
          el.batteryState.textContent = "设备未开放";
          return;
        }

        const battery = await navigator.getBattery();
        const render = () => {
          const pct = Math.round(battery.level * 100);
          el.batteryLabel.textContent = `电量 ${pct}%`;
          el.batteryState.textContent = battery.charging ? "充电中" : "使用电池";
          el.batteryFill.style.setProperty("--battery-level", `${pct}%`);
          el.batteryFill.closest(".battery-status").classList.toggle("is-charging", battery.charging);
          el.batteryFill.closest(".battery-status").classList.toggle("is-low", !battery.charging && pct <= 20);
        };

        battery.addEventListener("levelchange", render);
        battery.addEventListener("chargingchange", render);
        render();
      } catch (_) {
        el.batteryLabel.textContent = "电量不可用";
        el.batteryState.textContent = "读取失败";
      }
    }

    document.addEventListener("click", toggleDim);
    document.addEventListener("dblclick", () => location.reload());
    document.addEventListener("visibilitychange", () => {
      if (!document.hidden) requestWakeLock();
    });

    updateClock();
    renderWeatherPager();
    initWeatherSlider();
    renderPager();
    initSlider();
    updateWeather();
    updateBattery();
    requestWakeLock();
    setInterval(updateClock, 1000);
    setInterval(updateWeather, 15 * 60 * 1000);
    setInterval(updateBattery, 60 * 1000);
