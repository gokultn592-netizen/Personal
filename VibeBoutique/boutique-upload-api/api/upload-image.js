const B2 = require("backblaze-b2");

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

  if (!fileName || !fileBase64) {
    return res.status(400).json({ error: "Missing required parameters: fileName, fileBase64" });
  }

  // Retrieve environment variables
  const { B2_APP_KEY_ID, B2_APP_KEY, B2_BUCKET_ID, B2_BUCKET_NAME, B2_DOWNLOAD_URL } = process.env;

  // Development Fallback: If credentials are not set, return a mock Unsplash fashion photo
  if (!B2_APP_KEY_ID || !B2_APP_KEY || !B2_BUCKET_ID || !B2_BUCKET_NAME) {
    console.warn("B2 credentials are not set. Returning a mock photo for local development.");
    const mockPhotos = [
      "https://images.unsplash.com/photo-1515886657613-9f3515b0c78f?w=600&auto=format&fit=crop",
      "https://images.unsplash.com/photo-1539185441755-769473a23570?w=600&auto=format&fit=crop",
      "https://images.unsplash.com/photo-1596755094514-f87e34085b2c?w=600&auto=format&fit=crop",
      "https://images.unsplash.com/photo-1544441893-675973e31985?w=600&auto=format&fit=crop",
      "https://images.unsplash.com/photo-1496747611176-843222e1e57c?w=600&auto=format&fit=crop"
    ];
    const randomPhoto = mockPhotos[Math.floor(Math.random() * mockPhotos.length)];
    
    return res.status(200).json({
      success: true,
      imageUrl: randomPhoto,
      fileName: `mock-${Date.now()}-${fileName.replace(/\s+/g, "_")}`,
      isMock: true
    });
  }

  try {
    const b2 = new B2({
      applicationKeyId: B2_APP_KEY_ID,
      applicationKey: B2_APP_KEY
    });

    // 1. Authorize B2 Account
    await b2.authorize();

    // 2. Request upload token
    const uploadUrlResponse = await b2.getUploadUrl({
      bucketId: B2_BUCKET_ID
    });
    const { uploadUrl, authorizationToken } = uploadUrlResponse.data;

    // 3. Convert base64 payload to binary buffer
    const fileBuffer = Buffer.from(fileBase64, "base64");

    // 4. Generate unique filename to avoid conflict overwrites
    const uniqueFileName = `${Date.now()}-${fileName.replace(/\s+/g, "_")}`;

    // 5. Upload file data
    await b2.uploadFile({
      uploadUrl: uploadUrl,
      uploadAuthToken: authorizationToken,
      fileName: uniqueFileName,
      data: fileBuffer,
      mime: fileType || "image/jpeg"
    });

    // 6. Build target asset URL
    // Default format: https://f000.backblazeb2.com/file/bucketName/fileName
    const publicUrl = B2_DOWNLOAD_URL
      ? `${B2_DOWNLOAD_URL.replace(/\/$/, "")}/${uniqueFileName}`
      : `https://f000.backblazeb2.com/file/${B2_BUCKET_NAME}/${uniqueFileName}`;

    return res.status(200).json({
      success: true,
      imageUrl: publicUrl,
      fileName: uniqueFileName
    });

  } catch (error) {
    console.error("Backblaze B2 Upload Error: ", error);
    return res.status(500).json({
      error: "B2 Upload failed",
      details: error.message
    });
  }
};
