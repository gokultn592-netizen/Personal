module.exports = async (req, res) => {
  // Enable CORS manually
  res.setHeader("Access-Control-Allow-Origin", "*");
  res.setHeader("Access-Control-Allow-Methods", "POST, OPTIONS");
  res.setHeader("Access-Control-Allow-Headers", "Content-Type");

  // Handle CORS OPTIONS preflight
  if (req.method === "OPTIONS") {
    return res.status(200).end();
  }

  if (req.method !== "POST") {
    return res.status(405).json({ error: "Method not allowed" });
  }

  const { fileName, fileType, fileBase64 } = req.body;

  if (!fileBase64) {
    return res.status(400).json({ error: "Missing required parameter: fileBase64" });
  }

  // Use environment variable key, throw error if not configured
  const apiKey = process.env.IMGBB_API_KEY;
  if (!apiKey) {
    console.error("Missing process.env.IMGBB_API_KEY environment configuration.");
    return res.status(500).json({ error: "Server Configuration Error: Upload API key is missing." });
  }

  try {
    // Construct urlencoded parameters for ImageBB API
    const params = new URLSearchParams();
    params.append("image", fileBase64);

    // Call ImageBB upload endpoint
    const response = await fetch(`https://api.imgbb.com/1/upload?key=${apiKey}`, {
      method: "POST",
      body: params,
      headers: {
        "Content-Type": "application/x-www-form-urlencoded"
      }
    });

    const result = await response.json();

    if (response.ok && result.success && result.data && result.data.url) {
      return res.status(200).json({
        success: true,
        imageUrl: result.data.url,
        fileName: fileName || `img-${Date.now()}`
      });
    } else {
      throw new Error(result.error?.message || "ImageBB response failed");
    }

  } catch (error) {
    console.error("ImageBB Proxy Upload Error: ", error);
    return res.status(500).json({
      error: "ImageBB Upload failed via proxy",
      details: error.message
    });
  }
};
