import { ProductStore, SearchIndex } from "./ports";

// Use-case: rebuild the search index from the product store.
export async function reindexCatalog(
  store: ProductStore,
  index: SearchIndex,
): Promise<number> {
  await index.clear();
  const products = await store.all();
  for (const p of products) {
    await index.put(p);
  }
  return products.length;
}
