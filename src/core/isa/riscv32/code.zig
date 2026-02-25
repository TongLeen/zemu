pub const R = packed struct {
    opcode: u7,
    rd: u5,
    funct3: u3,
    rs1: u5,
    rs2: u5,
    funct7: u7,
};

pub const I = packed struct {
    opcode: u7,
    rd: u5,
    funct3: u3,
    rs1: u5,
    imm: u12,
};

pub const S = packed struct {
    opcode: u7,
    imm_4_0: u5,
    funct3: u3,
    rs1: u5,
    rs2: u5,
    imm_11_5: u7,

    pub fn imm(self: @This()) u12 {
        const t: u12 = self.imm_11_5;
        return (t << 5) | self.imm_4_0;
    }
};

pub const B = packed struct {
    opcode: u7,
    imm_11: u1,
    imm_4_1: u4,
    funct3: u3,
    rs1: u5,
    rs2: u5,
    imm_10_5: u6,
    imm_12: u1,

    pub fn imm(self: @This()) u12 {
        const imm_t = packed struct {
            imm_4_1: u4,
            imm_10_5: u6,
            imm_11: u1,
            imm_12: u1,
        };
        return @bitCast(imm_t{
            .imm_4_1 = self.imm_4_1,
            .imm_10_5 = self.imm_10_5,
            .imm_11 = self.imm_11,
            .imm_12 = self.imm_12,
        });
    }
};

pub const U = packed struct {
    opcode: u7,
    rd: u5,
    imm: u20,
};

pub const J = packed struct {
    opcode: u7,
    rd: u5,
    imm_19_12: u8,
    imm_11: u1,
    imm_10_1: u10,
    imm_20: u1,

    pub fn imm(self: @This()) u20 {
        const imm_t = packed struct {
            imm_10_1: u10,
            imm_11: u1,
            imm_19_12: u8,
            imm_20: u1,
        };
        return @bitCast(imm_t{
            .imm_10_1 = self.imm_10_1,
            .imm_11 = self.imm_11,
            .imm_19_12 = self.imm_19_12,
            .imm_20 = self.imm_20,
        });
    }
};

pub const CR = packed struct {
    opcode: u2,
    rs2: u5,
    rd_rs1: u5,
    funct4: u4,
};

pub const CI = packed struct {
    opcode: u2,
    imm0: u5,
    rd_rs1: u5,
    imm1: u1,
    funct3: u3,
};

pub const CSS = packed struct {
    opcode: u2,
    rs2: u5,
    imm: u6,
    funct3: u3,
};

pub const CIW = packed struct {
    opcode: u2,
    rd_: u3,
    imm: u8,
    funct3: u3,
};

pub const CL = packed struct {
    opcode: u2,
    rd_: u3,
    imm0: u2,
    rs1_: u3,
    imm1: u3,
    funct3: u3,
};

pub const CS = packed struct {
    opcode: u2,
    rs2_: u3,
    imm0: u2,
    rs1_: u3,
    imm1: u3,
    funct3: u3,
};

pub const CA = packed struct {
    opcode: u2,
    rs2_: u3,
    funct2: u2,
    rd_rs1_: u3,
    funct6: u6,
};

pub const CB = packed struct {
    opcode: u2,
    offset0: u5,
    rs1_: u3,
    offset1: u3,
    funct3: u3,
};

pub const CJ = packed struct {
    opcode: u2,
    imm: u11,
    funct3: u3,
};

pub const Error = error{
    CodeIllegal,
    CodeNotFound,
    CodeReserved,
};
