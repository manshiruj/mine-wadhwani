import ApiResponse from "../Utils/Apiresponse.js";

// Roboflow hosted PPE model. Key stays server-side (ROBOFLOW_API_KEY).
// Default: Roboflow's Construction Site Safety model (Hardhat / NO-Hardhat / Safety Vest / NO-Safety Vest / Mask / NO-Mask / Person ...).
const ROBOFLOW_MODEL = process.env.ROBOFLOW_MODEL || "construction-site-safety/27";

// POST { image: "<base64>" } -> Roboflow response { predictions: [...], image: { width, height } }
const analyze_ppe = async (req, res) => {
  try {
    let { image } = req.body ?? {};
    if (typeof image !== "string" || !image) {
      return res.status(400).json(ApiResponse.error("Missing image field in request body", 400));
    }
    image = image.replace(/^data:image\/\w+;base64,/, "");

    const rf = await fetch(
      `https://serverless.roboflow.com/${ROBOFLOW_MODEL}?api_key=${process.env.ROBOFLOW_API_KEY}`,
      {
        method: "POST",
        headers: { "Content-Type": "application/x-www-form-urlencoded" },
        body: image,
      },
    );
    const json = await rf.json().catch(() => ({}));
    if (!rf.ok) {
      console.error("Roboflow error:", rf.status, json);
      return res.status(502).json(ApiResponse.error(`PPE analysis failed: ${json.message ?? rf.status}`, 502));
    }
    return res.status(200).json(json);
  } catch (error) {
    console.error("Roboflow proxy error:", error.message);
    return res.status(500).json(ApiResponse.error(`PPE analysis failed: ${error.message}`, 500));
  }
};

export { analyze_ppe };
