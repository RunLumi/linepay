// Exact rational arithmetic. Payroll money never enters Number or binary floating point.
const gcd = (a, b) => {
  a = a < 0n ? -a : a;
  b = b < 0n ? -b : b;
  while (b) [a, b] = [b, a % b];
  return a;
};
export class Decimal {
  constructor(n, d = 1n) {
    if (d === 0n) throw Error("Division by zero");
    if (d < 0n) {
      n = -n;
      d = -d;
    }
    const g = gcd(n, d);
    this.n = n / g;
    this.d = d / g;
    Object.freeze(this);
  }
  static parse(text) {
    if (typeof text !== "string" || !/^-?\d{1,30}(\.\d{1,12})?$/.test(text))
      throw Error(
        "Enter a decimal number, without commas or exponent notation.",
      );
    const [whole, tail = ""] = text.split(".");
    return new Decimal(BigInt(whole + tail), 10n ** BigInt(tail.length));
  }
  add(b) {
    return new Decimal(this.n * b.d + b.n * this.d, this.d * b.d);
  }
  sub(b) {
    return new Decimal(this.n * b.d - b.n * this.d, this.d * b.d);
  }
  mul(b) {
    return new Decimal(this.n * b.n, this.d * b.d);
  }
  div(b) {
    return new Decimal(this.n * b.d, this.d * b.n);
  }
  compare(b) {
    const v = this.n * b.d - b.n * this.d;
    return v < 0n ? -1 : v > 0n ? 1 : 0;
  }
  units(scale = 2, mode = "halfUp") {
    if (!Number.isInteger(scale) || scale < 0 || scale > 8)
      throw Error("Unsupported rounding scale");
    if (!["halfUp", "bankers", "down", "up"].includes(mode))
      throw Error("Unsupported rounding mode");
    const numerator = this.n * 10n ** BigInt(scale),
      q = numerator / this.d,
      r = numerator % this.d,
      sign = numerator < 0n ? -1n : 1n;
    if (!r) return q;
    const magnitude = r < 0n ? -r : r;
    if (mode === "down") return numerator < 0n ? q - 1n : q;
    if (mode === "up") return numerator > 0n ? q + 1n : q;
    if (mode !== "halfUp" && mode !== "bankers")
      throw Error("Unsupported rounding mode");
    const twice = magnitude * 2n;
    return (
      q +
      (twice > this.d ||
      (twice === this.d && (mode === "halfUp" || q % 2n !== 0n))
        ? sign
        : 0n)
    );
  }
  text() {
    let power = 1n;
    for (let scale = 0; scale <= 26; scale++, power *= 10n)
      if (power % this.d === 0n) {
        const value = unitsText(this.n * (power / this.d), scale);
        return value.includes(".")
          ? value.replace(/0+$/, "").replace(/\.$/, "")
          : value;
      }
    throw Error("This rational needs an explicit display rounding policy.");
  }
  fixed(scale = 2, mode = "halfUp") {
    return unitsText(this.units(scale, mode), scale);
  }
}
export function unitsText(value, scale) {
  const sign = value < 0n ? "-" : "";
  const s = (value < 0n ? -value : value).toString().padStart(scale + 1, "0");
  return scale ? sign + s.slice(0, -scale) + "." + s.slice(-scale) : sign + s;
}
export const dec = Decimal.parse,
  zero = dec("0"),
  one = dec("1");
export const seconds = (value) => new Decimal(BigInt(value));
