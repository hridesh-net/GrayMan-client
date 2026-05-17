import AsyncStorage from '@react-native-async-storage/async-storage';
import * as SecureStore from 'expo-secure-store';

const JWT_KEY = 'grayman.jwt';
const WORKER_ID_KEY = 'grayman.workerID';

let cachedToken = null;

export const tokenStore = {
  get token() {
    return cachedToken;
  },

  get workerID() {
    return AsyncStorage.getItem(WORKER_ID_KEY);
  },

  async load() {
    try {
      cachedToken = await SecureStore.getItemAsync(JWT_KEY);
    } catch {
      cachedToken = await AsyncStorage.getItem(JWT_KEY);
    }
    return cachedToken;
  },

  async save(token, workerId) {
    cachedToken = token;
    try {
      await SecureStore.setItemAsync(JWT_KEY, token);
    } catch {
      await AsyncStorage.setItem(JWT_KEY, token);
    }
    if (workerId) {
      await AsyncStorage.setItem(WORKER_ID_KEY, workerId);
    }
  },

  async clear() {
    cachedToken = null;
    try {
      await SecureStore.deleteItemAsync(JWT_KEY);
    } catch { /* ignore */ }
    await AsyncStorage.multiRemove([JWT_KEY, WORKER_ID_KEY]);
  },

  async getWorkerID() {
    return AsyncStorage.getItem(WORKER_ID_KEY);
  },
};
