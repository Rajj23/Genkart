require('dotenv').config();
const mongoose = require('mongoose');
const Products = require('../models/productSchema');

const seedProducts = [
  {
    name: 'Classic Cotton T-Shirt',
    category: 'tshirts',
    vendor: 'GenRio',
    MRPprice: 999,
    sellingPrice: 499,
    description: 'Soft everyday cotton tee with a relaxed fit and breathable fabric.',
    image: 'https://res.cloudinary.com/demo/image/upload/sample.jpg',
    additionalImages: [],
    quantity: 40,
    trend: true,
    offer: true,
  },
  {
    name: 'Urban Street T-Shirt',
    category: 'tshirts',
    vendor: 'GenRio',
    MRPprice: 1299,
    sellingPrice: 699,
    description: 'Street-style graphic tee designed for casual daily wear.',
    image: 'https://res.cloudinary.com/demo/image/upload/sample.jpg',
    additionalImages: [],
    quantity: 30,
    trend: true,
    offer: false,
  },
  {
    name: 'Slim Fit Casual Shirt',
    category: 'casuals',
    vendor: 'GenRio',
    MRPprice: 1499,
    sellingPrice: 899,
    description: 'Lightweight casual shirt for office and weekend wear.',
    image: 'https://res.cloudinary.com/demo/image/upload/sample.jpg',
    additionalImages: [],
    quantity: 25,
    trend: false,
    offer: true,
  },
  {
    name: 'Relaxed Fit Casual Shirt',
    category: 'casuals',
    vendor: 'GenRio',
    MRPprice: 1699,
    sellingPrice: 999,
    description: 'Comfort-first shirt with a clean silhouette and soft hand feel.',
    image: 'https://res.cloudinary.com/demo/image/upload/sample.jpg',
    additionalImages: [],
    quantity: 18,
    trend: true,
    offer: false,
  },
  {
    name: 'Premium Polo T-Shirt',
    category: 'tshirts',
    vendor: 'GenRio',
    MRPprice: 1199,
    sellingPrice: 749,
    description: 'Smart polo with a structured collar for a neat casual look.',
    image: 'https://res.cloudinary.com/demo/image/upload/sample.jpg',
    additionalImages: [],
    quantity: 22,
    trend: false,
    offer: true,
  },
  {
    name: 'Everyday Cotton Tee',
    category: 'tshirts',
    vendor: 'GenRio',
    MRPprice: 899,
    sellingPrice: 399,
    description: 'Basic essential tee with a versatile fit for daily use.',
    image: 'https://res.cloudinary.com/demo/image/upload/sample.jpg',
    additionalImages: [],
    quantity: 55,
    trend: false,
    offer: true,
  },
];

async function seed() {
  if (!process.env.MONGO_URI) {
    throw new Error('MONGO_URI is missing in .env');
  }

  await mongoose.connect(process.env.MONGO_URI);
  await Products.deleteMany({});
  const inserted = await Products.insertMany(seedProducts);
  console.log(`Seeded ${inserted.length} products.`);
  await mongoose.disconnect();
}

seed()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('Seed failed:', error.message);
    process.exit(1);
  });
