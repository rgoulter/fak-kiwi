For LED blinking:

```
        led_1.write(false);
        for (0..1000000) |_| {
            asm volatile ("nop");
        }

        led_1.write(true);
        for (0..1000000) |_| {
            asm volatile ("nop");
        }
```

