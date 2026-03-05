import { expect, test } from "@playwright/test";

async function assertSuccessStats(page) {
  await expect(page.getByTestId("status-text")).toContainText("Success");

  const inSize = Number(await page.getByTestId("in-size").innerText());
  const outSize = Number(await page.getByTestId("out-size").innerText());
  const growth = Number((await page.getByTestId("growth").innerText()).replace("%", ""));

  expect(inSize).toBeGreaterThan(0);
  expect(outSize).toBeGreaterThan(inSize);
  expect(growth).toBeGreaterThan(0);
}

async function setInputEditor(page, text) {
  const editor = page.locator(".monaco-editor").first();
  await editor.click({ position: { x: 24, y: 24 } });
  await page.keyboard.press("Control+A");
  await page.keyboard.press("Backspace");
  if (text.length > 0) {
    await page.keyboard.type(text);
  }
}

test("playground obfuscates wasm hex sample", async ({ page }) => {
  await page.goto("/");

  await expect(page.getByText("wasm-obfuscator Playground")).toBeVisible();

  await page.getByTestId("sample-button").click();
  await page.getByTestId("run-button").click();
  await assertSuccessStats(page);
});

test("playground obfuscates wat sample", async ({ page }) => {
  await page.goto("/");
  await page.getByTestId("format-select").selectOption("wat");
  await page.getByTestId("sample-button").click();
  await page.getByTestId("run-button").click();
  await assertSuccessStats(page);
});

test("playground obfuscates custom wat input", async ({ page }) => {
  await page.goto("/");
  await page.getByTestId("format-select").selectOption("wat");
  await setInputEditor(
    page,
    "(module (func (export \"add\") (param i32 i32) (result i32) local.get 0 local.get 1 i32.add))",
  );
  await page.getByTestId("run-button").click();
  await assertSuccessStats(page);
});

test("playground shows validation error for odd-length hex", async ({ page }) => {
  await page.goto("/");
  await setInputEditor(page, "abc");
  await page.getByTestId("run-button").click();
  await expect(page.getByTestId("status-text")).toContainText("Error: Hex length must be even.");
});

test("playground shows validation error for empty input", async ({ page }) => {
  await page.goto("/");
  await setInputEditor(page, "");
  await page.getByTestId("run-button").click();
  await expect(page.getByTestId("status-text")).toContainText("Error: Input is empty.");
});
