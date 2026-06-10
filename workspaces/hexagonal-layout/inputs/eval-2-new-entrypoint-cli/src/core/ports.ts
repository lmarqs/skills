// Ports: what the reindex use-case needs from the outside world.
// The core declares these; adapters implement them.

export interface Product {
  id: string;
  title: string;
  tags: string[];
}

export interface ProductStore {
  all(): Promise<Product[]>;
}

export interface SearchIndex {
  put(product: Product): Promise<void>;
  clear(): Promise<void>;
}
