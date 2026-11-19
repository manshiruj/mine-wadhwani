import ApiResponse from "../Utils/Apiresponse.js";

// aqi.in device API proxy. Credentials stay server-side (AQI_EMAIL / AQI_PASSWORD).
const AQI_BASE = "https://airquality.aqi.in/api/v1";
let cachedToken = null;

const login = async () => {
  const res = await fetch(`${AQI_BASE}/login`, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      email: process.env.AQI_EMAIL ?? "",
      password: process.env.AQI_PASSWORD ?? "",
    }),
  });
  const json = await res.json().catch(() => ({}));
  // Doc only says "account details with token"; accept the common shapes.
  const token = json.token ?? json.data?.token ?? json.access_token ?? json.data?.access_token;
  if (!res.ok || !token) {
    throw new Error(`aqi.in login failed: ${json.message ?? res.status}`);
  }
  cachedToken = token;
  return token;
};

// GET with cached token; re-login once if the token expired.
const aqiGet = async (path, params = {}, extraHeaders = {}) => {
  for (let attempt = 0; attempt < 2; attempt++) {
    const token = cachedToken ?? (await login());
    const url = `${AQI_BASE}/${path}?${new URLSearchParams(params)}`;
    const res = await fetch(url, {
      headers: { Authorization: `bearer ${token}`, ...extraHeaders },
    });
    if (res.status === 401 && attempt === 0) {
      cachedToken = null;
      continue;
    }
    const json = await res.json().catch(() => ({}));
    if (!res.ok) throw new Error(`aqi.in ${path} failed: ${json.message ?? res.status}`);
    return json;
  }
};

const toSensorMap = (realtime = []) =>
  Object.fromEntries(
    realtime.map((s) => [s.sensorname, { id: s.sensorid, value: s.sensorvalue, unit: s.unit }]),
  );

// Device list with realtime sensor readings flattened to { sensorname: { id, value, unit } }.
const get_devices = async (req, res) => {
  try {
    const json = await aqiGet("GetAllUserDevices");
    const devices = (json.data ?? []).map((d) => ({
      serialNo: d.serialNo,
      devicename: d.devicename,
      dev_type: d.dev_type,
      isOnline: d.isOnline,
      last_updated: d.last_updated,
      timeago: d.timeago,
      lat: d.adddevicelat ?? d.lat,
      lon: d.adddevicelon ?? d.lon,
      sensors: toSensorMap(d.realtime),
    }));
    return res.status(200).json(ApiResponse.success(devices));
  } catch (error) {
    return res.status(502).json(ApiResponse.error(error.message, 502));
  }
};

// Latest reading of one device: ?serialNo=..., else AQI_DEVICE_SERIAL, else first device.
const get_latest = async (req, res) => {
  try {
    const json = await aqiGet("GetAllUserDevices");
    const list = json.data ?? [];
    const serial = req.query.serialNo ?? process.env.AQI_DEVICE_SERIAL;
    const d = serial ? list.find((x) => x.serialNo === serial) : list[0];
    if (!d) return res.status(404).json(ApiResponse.error("No AQM device found", 404));
    return res.status(200).json(
      ApiResponse.success({
        serialNo: d.serialNo,
        devicename: d.devicename,
        isOnline: d.isOnline,
        last_updated: d.last_updated,
        timeago: d.timeago,
        sensors: toSensorMap(d.realtime),
      }),
    );
  } catch (error) {
    return res.status(502).json(ApiResponse.error(error.message, 502));
  }
};

// Historic data. Query: serialNo, time (1|2|3), slottype (1-6), isdaterange, fromdate, todate, sensorparam (e.g. "[1,3]").
const get_history = async (req, res) => {
  try {
    const { serialNo, time = "1", slottype = "3", isdaterange = "0", fromdate, todate, sensorparam } = req.query;
    if (!serialNo) return res.status(400).json(ApiResponse.error("serialNo is required", 400));
    const params = { serialno: serialNo, time, slottype, isdaterange };
    if (isdaterange === "1") Object.assign(params, { fromdate, todate });
    const json = await aqiGet(
      "GetDeviceDataForAnyTimePeriod",
      params,
      sensorparam ? { Sensorparam: sensorparam } : {},
    );
    return res.status(200).json(ApiResponse.success(json.data ?? []));
  } catch (error) {
    return res.status(502).json(ApiResponse.error(error.message, 502));
  }
};

// Rainfall averages. Query: serialNo, sensorId (e.g. 305).
const get_rainfall = async (req, res) => {
  try {
    const { serialNo, sensorId } = req.query;
    if (!serialNo || !sensorId) {
      return res.status(400).json(ApiResponse.error("serialNo and sensorId are required", 400));
    }
    const json = await aqiGet("GetRainfallAvgDataForDevices", { serialno: serialNo, sensorid: sensorId });
    return res.status(200).json(ApiResponse.success(json.data ?? {}));
  } catch (error) {
    return res.status(502).json(ApiResponse.error(error.message, 502));
  }
};

export { get_devices, get_latest, get_history, get_rainfall, aqiGet, toSensorMap };
