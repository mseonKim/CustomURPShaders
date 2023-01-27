using System;
using System.Collections;
using System.Collections.Generic;
using System.Runtime.CompilerServices;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class NoiseTextureRendererFeature : ScriptableRendererFeature
{
    private NoisePass m_Pass;
    public RenderPassEvent injectionPoint = RenderPassEvent.AfterRenderingOpaques;
    public ComputeShader computeShader;
    public Material targetMaterial;
    public int[] size = new int[2] { 1024, 1024 };


    public override void Create()
    {
        m_Pass = new NoisePass();
        m_Pass.renderPassEvent = injectionPoint;
        m_Pass.Setup(computeShader, size, targetMaterial);
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        renderer.EnqueuePass(m_Pass);
    }

    protected override void Dispose(bool disposing)
    {
        m_Pass.Dispose();
    }


    class NoisePass : ScriptableRenderPass
    {
        private ComputeShader m_computeShader;
        private ComputeBuffer m_sizeBuffer;
        private RenderTexture m_outputTexture;
        private Material m_TargetMaterial;
        private int m_KernelIndex;
        private int[] m_Size;
        private float m_NumThreads = 32f;
        private static readonly int m_SizeID = Shader.PropertyToID("gSize");
        private static readonly int m_OutputID = Shader.PropertyToID("gOutput");


        public void Setup(ComputeShader computeShader, int[] size, Material material)
        {
            m_computeShader = computeShader;
            m_KernelIndex = m_computeShader.FindKernel("NoiseCSMain");
            m_Size = size;
            m_sizeBuffer = new ComputeBuffer(1, 8);
            m_outputTexture = new RenderTexture(size[0], size[1], 1, RenderTextureFormat.ARGB32);
            m_outputTexture.enableRandomWrite = true;
            m_outputTexture.Create();
            m_sizeBuffer.SetData(size);
            m_computeShader.SetBuffer(m_KernelIndex, m_SizeID, m_sizeBuffer);
            m_computeShader.SetTexture(m_KernelIndex, m_OutputID, m_outputTexture, 0);
            m_TargetMaterial = material;
        }

        public void Dispose()
        {
            m_sizeBuffer.Release();
            m_outputTexture.Release();
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            if (m_computeShader != null)
            {
                m_computeShader.Dispatch(m_KernelIndex, Mathf.CeilToInt(m_Size[0] / m_NumThreads), Mathf.CeilToInt(m_Size[1] / m_NumThreads), 1);
                m_TargetMaterial.SetTexture("_MainTex", m_outputTexture);
            }
        }

    }
}
