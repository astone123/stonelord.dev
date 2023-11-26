import { h, Fragment } from "preact";

interface IconLinkProps {
  href: string;
  altText: string;
  iconPath: string;
  darkIconPath?: string;
}

export function IconLink({
  href,
  altText,
  iconPath,
  darkIconPath,
}: IconLinkProps) {
  return (
    <a href={href} target="_blank">
      <img
        class={`${
          darkIconPath ? "dark:hidden" : ""
        } w-[45px] sm:w-[30px] sm:hover:w-[35px] sm:motion-reduce:hover:w-[30px] transition-all duration-200 motion-reduce:transition-none`}
        alt={altText}
        src={iconPath}
      />
      {darkIconPath && (
        <img
          class="hidden dark:block w-[45px] sm:w-[30px] sm:hover:w-[35px] sm:motion-reduce:hover:w-[30px] transition-all duration-200 motion-reduce:transition-none"
          alt={altText}
          src={darkIconPath}
        />
      )}
    </a>
  );
}
