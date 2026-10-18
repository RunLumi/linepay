const MAX = 67108864,
  encoder = new TextEncoder(),
  magic = encoder.encode("LPBENC01");
function passwordBytes(password, creating) {
  if (typeof password !== "string") throw Error("Enter a password.");
  const normalized = password.normalize("NFC"),
    bytes = encoder.encode(normalized);
  if (
    !bytes.length ||
    bytes.length > 1024 ||
    (creating && [...normalized].length < 12)
  )
    throw Error(
      "Use at least 12 characters and no more than 1,024 UTF-8 bytes. Spaces are kept.",
    );
  return bytes;
}
async function keyFor(bytes, salt, usage) {
  const password = await crypto.subtle.importKey(
    "raw",
    bytes,
    "PBKDF2",
    false,
    ["deriveKey"],
  );
  return crypto.subtle.deriveKey(
    { name: "PBKDF2", hash: "SHA-256", salt, iterations: 600000 },
    password,
    { name: "AES-GCM", length: 256 },
    false,
    [usage],
  );
}
export async function encryptBackup(plaintext, password) {
  if (
    !(plaintext instanceof Uint8Array) ||
    !plaintext.length ||
    plaintext.length > MAX - 60
  )
    throw Error("Backup exceeds the supported file size.");
  const bytes = passwordBytes(password, true),
    header = new Uint8Array(44),
    view = new DataView(header.buffer);
  header.set(magic);
  view.setUint32(8, 600000);
  crypto.getRandomValues(header.subarray(12, 28));
  crypto.getRandomValues(header.subarray(28, 40));
  view.setUint32(40, plaintext.length);
  try {
    const key = await keyFor(bytes, header.subarray(12, 28), "encrypt");
    const ciphertext = await crypto.subtle.encrypt(
      {
        name: "AES-GCM",
        iv: header.subarray(28, 40),
        additionalData: header,
        tagLength: 128,
      },
      key,
      plaintext,
    );
    const result = new Uint8Array(ciphertext.byteLength + 44);
    result.set(header);
    result.set(new Uint8Array(ciphertext), 44);
    return result;
  } finally {
    bytes.fill(0);
  }
}
export async function decryptBackup(encoded, password) {
  if (
    !(encoded instanceof Uint8Array) ||
    encoded.length < 61 ||
    encoded.length > MAX
  )
    throw Error("Unsupported or oversized backup.");
  const header = encoded.subarray(0, 44),
    view = new DataView(encoded.buffer, encoded.byteOffset, 44),
    length = view.getUint32(40);
  if (
    !magic.every((x, i) => header[i] === x) ||
    view.getUint32(8) !== 600000 ||
    length < 1 ||
    length + 60 !== encoded.length
  )
    throw Error("Unsupported or damaged protected backup.");
  const bytes = passwordBytes(password, false);
  try {
    const key = await keyFor(bytes, header.subarray(12, 28), "decrypt");
    return new Uint8Array(
      await crypto.subtle.decrypt(
        {
          name: "AES-GCM",
          iv: header.subarray(28, 40),
          additionalData: header,
          tagLength: 128,
        },
        key,
        encoded.subarray(44),
      ),
    );
  } catch {
    throw Error(
      "Could not unlock this backup. Check the password and original file.",
    );
  } finally {
    bytes.fill(0);
  }
}
