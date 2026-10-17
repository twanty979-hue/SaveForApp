import React from "react";
import Image from "next/image";

interface IPhone17ProMaxProps {
  src?: string;
  alt?: string;
  children?: React.ReactNode;
  className?: string;
  variant?: "black" | "natural" | "desert";
  priority?: boolean;
}

export function IPhone17ProMax({
  src,
  alt = "App Screen",
  children,
  className = "",
  variant = "black",
  priority = false,
}: IPhone17ProMaxProps) {
  const frameImg = {
    black: "/images/mockups/iphone_16_pro_max_black.png",
    natural: "/images/mockups/iphone_16_pro_max_natural.png",
    desert: "/images/mockups/iphone_16_pro_max_desert.png",
  }[variant] || "/images/mockups/iphone_16_pro_max_black.png";

  // Pre-composited High-Resolution Mockup Mode (Ultra crisp, 100% authentic)
  if (src) {
    return (
      <div className={`relative inline-block select-none group ${className}`}>
        <div className="relative transition-transform duration-300 hover:scale-[1.02]">
          {/* Authentic ambient floor drop shadow */}
          <div className="absolute -bottom-4 left-1/2 -translate-x-1/2 w-[82%] h-7 bg-black/25 blur-lg rounded-[100%] pointer-events-none transition-opacity duration-300 group-hover:bg-black/35" />

          <Image
            src={src}
            alt={alt}
            width={1470}
            height={3000}
            sizes="(max-width: 640px) 260px, 380px"
            className="w-full h-auto object-contain select-none pointer-events-none drop-shadow-[0_15px_30px_rgba(0,0,0,0.18)]"
            priority={priority}
          />
        </div>
      </div>
    );
  }

  // Interactive Live DOM Mode (Hero Section)
  return (
    <div className={`relative inline-block select-none ${className}`}>
      {/* Soft floor shadow */}
      <div className="absolute -bottom-4 left-1/2 -translate-x-1/2 w-[82%] h-7 bg-black/25 blur-lg rounded-[100%] pointer-events-none" />

      {/* Frame Container with Native 1470x3000 Proportions */}
      <div className="relative w-full aspect-[1470/3000] drop-shadow-[0_20px_35px_rgba(0,0,0,0.22)]">
        {/* Screen Content Layer (Positioned behind the hardware bezel) */}
        <div
          className="absolute z-10 overflow-hidden flex flex-col"
          style={{
            left: "5.102%",
            top: "2.2%",
            width: "89.796%",
            height: "95.6%",
            borderRadius: "44px",
          }}
        >
          {children}
        </div>

        {/* Real Apple Titanium Hardware Frame Overlay */}
        <Image
          src={frameImg}
          alt="iPhone Frame"
          fill
          sizes="(max-width: 640px) 320px, 360px"
          className="pointer-events-none z-30 select-none object-contain"
          priority={priority}
        />
      </div>
    </div>
  );
}

export default IPhone17ProMax;
