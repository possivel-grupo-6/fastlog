'use client';

import React, { useState } from 'react';

function Home() {
  const [trackingNumber, setTrackingNumber] = useState('');
  const [status, setStatus] = useState(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);

  const API_BASE_URL = process.env.NEXT_PUBLIC_API_URL;

  const handleTrack = async () => {
    setLoading(true);
    setError(null);
    setStatus(null);

    try {
      const response = await fetch(`http://${API_BASE_URL}/buy/${trackingNumber}`);
      const data = await response.json();
      if(data){
        setStatus(data);
      } else{
          throw new Error('Número de rastreamento não encontrado.');
      }
      console.log('Status: ', status)


      return
      

    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-gray-100 flex flex-col items-center justify-center p-4">
      <h1 className="text-3xl font-bold mb-6 text-gray-800">Rastreio de Entregas - FastLog</h1>
      <div className="bg-white p-6 rounded-lg shadow-lg w-full max-w-md">
        <label className="block text-gray-700 text-sm font-bold mb-2" htmlFor="trackingNumber">
          Número de Rastreamento
        </label>
        <input
          type="text"
          id="trackingNumber"
          value={trackingNumber}
          onChange={(e) => setTrackingNumber(e.target.value)}
          className="w-full px-3 py-2 border rounded-md focus:outline-none focus:border-blue-500"
          placeholder="Digite o número de rastreamento"
        />
        <button
          onClick={handleTrack}
          disabled={!trackingNumber}
          className="w-full mt-4 bg-blue-500 text-white py-2 rounded-md hover:bg-blue-600 disabled:opacity-50"
        >
          {loading ? 'Buscando...' : 'Rastrear'}
        </button>

        {error && <p className="text-red-500 mt-4">{error}</p>}
        
        {status && (
          <div className="mt-6 flex flex-col gap-2">
            <h2 className="text-xl font-semibold">Status da Entrega</h2>
            <div className="flex flex-col gap-1 [&>p]:opacity-80">
            <p><strong>Nome:</strong> {status.product}</p>
            <p><strong>Preço:</strong> {status.price}</p>
            <p><strong>Status:</strong> {status.status}</p>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}

export default Home;