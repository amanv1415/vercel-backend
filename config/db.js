const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');

const connectDB = async () => {
  try {
    const uri = process.env.MONGODB_URI;
    
    if (!uri && process.env.NODE_ENV === 'production') {
      throw new Error('MONGODB_URI must be set in production');
    }
    
    if (!uri) {
      console.log('⚠️  Using in-memory MongoDB for development');
      const mongod = await MongoMemoryServer.create();
      const memoryUri = mongod.getUri();
      await mongoose.connect(memoryUri);
    } else {
      await mongoose.connect(uri);
    }
    
    console.log('✅ MongoDB connected');
  } catch (error) {
    console.error('❌ MongoDB connection error:', error.message);
    process.exit(1);
  }
};

module.exports = connectDB;
