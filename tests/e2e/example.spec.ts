import { expect, test, type Page } from '@playwright/test';

const editorFrame = 'iframe[name="frameEditor"]';

async function openExampleEditor(page: Page, name: string | RegExp, value: string) {
  const popupPromise = page.waitForEvent('popup');
  await page.getByRole('link', { name }).click();
  const editorPage = await popupPromise;

  await editorPage.locator(editorFrame).waitFor({ state: 'visible' });
  const editorArea = editorPage.frameLocator(editorFrame).locator('#area_id');
  await expect(editorArea).toBeVisible();
  await editorArea.fill(value);
  await expect(editorArea).toHaveValue(value);

  await editorPage.close();
}

test('creates and edits example document types', async ({ page }) => {
  await page.goto('/example/');
  await expect(page.getByRole('link', { name: 'Document' })).toBeVisible();

  await openExampleEditor(page, 'Document', 'OnlyOffice');
  await openExampleEditor(page, 'Spreadsheet', 'OnlyOffice ');
  await openExampleEditor(page, 'Presentation', 'OnlyOffice');
  await openExampleEditor(page, 'PDF form', 'OnlyOffice');
});
